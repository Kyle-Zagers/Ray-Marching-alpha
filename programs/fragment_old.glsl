#version 330 core
#include hg_sdf.glsl

layout (location = 0) out vec4 fragColor;

precision mediump float;

uniform vec2 u_resolution;
//uniform vec2 u_mouse;
uniform float u_time;
uniform float u_scroll;
uniform int u_key;
uniform vec3 u_camPos;

const float MAX_STEPS = 100.0;
const float MIN_DIST_TO_SDF = 0.001;
const float MAX_DIST_TO_TRAVEL = 100.0;
const float EPSILON = 0.01;

struct Light {
  float size;
  vec3 pos;
  vec3 color;
};

float map(vec3 pos) {

  // box 1
  float boxDist = fBox(pos-vec3(3*cos(u_time), 0.0, 3*sin(u_time)), vec3(1));
  //float boxDist2 = sdfBox(vec3(-10,-10,-10),vec3(1.0));

  float kyleBox = fBox(pos-vec3(3*cos(u_time), 1.5, 3*sin(u_time)), vec3(0.5));

  // plane
  vec3 normal = vec3(0.0, 1.0, 0.0);
  float planeDist = fPlane(pos, normal, 1.0);

  // sphere
  float sphereDist = fSphere(pos-vec3(9, 2 , -1), 1);
  float box = fBox(pos-vec3(7, 0.5, -1), vec3(0.5));

  float blob = fBlob(pos-vec3(0, 1, 0));

  float maxDist = min(planeDist, blob);
  //maxDist = min(maxDist, boxDist);
  //maxDist = min(maxDist, kyleBox);
  maxDist = min(maxDist, box);
    
  return maxDist;
}

float rayMarch(vec3 rOrigin, vec3 rDirection, float maxDistToTravel) {
  float rDist = 0.0;

  for (float i = 0.0; i < MAX_STEPS; i++) {
    vec3 currentPos = rOrigin + rDirection * rDist;
    float maxDist = map(currentPos);

    rDist += maxDist;

    if (rDist > maxDistToTravel || maxDist < MIN_DIST_TO_SDF) {
      break;
    }
  }

  return rDist;
}

vec3 getNormal(vec3 p) {
    vec2 e = vec2(EPSILON, 0.0);
    vec3 n = vec3(map(p)) - vec3(map(p - e.xyy), map(p - e.yxy), map(p - e.yyx));
    return normalize(n);
}

float softShadow2(vec3 rOrigin, vec3 rDirection, float lightSize) {
  float t = 0.01;
  float res = 1.0;
  float maxt = 3.0;
  for(int i = 0; i<256 && t<maxt; i++)
  {
    float h = map(rOrigin + t*rDirection);
    res = min(res, h/(lightSize*t));
    t += clamp(h, 0.005, 0.50);
    if(res < -1.0 || t>maxt) break;
  }
  res = max(res, -1.0);
  return 0.25*(1.0+res)*(1.0+res)*(2.0-res);
}




float softShadow(vec3 pos, Light lightSource) {
  float shadow = 1.0;
  float dist = 0.01;
  vec3 lightPos = normalize(lightSource.pos);
  for (int i=0; i < MAX_STEPS; i++) {
    float hit = map(pos + lightPos * dist);
    shadow = min(shadow, hit / (dist * lightSource.size));
    dist += hit;
    if (hit < MIN_DIST_TO_SDF || dist > MAX_DIST_TO_TRAVEL) break;
  }
  return clamp(shadow, 0.0, 1.0);
}

float ambientOcclusion(vec3 pos, vec3 normal) {
  float occ = 0.0;
  float weight = 1.0;
  for (int i = 0; i < 8; i++) {
    float len = 0.01 + 0.02 * float(i * i);
    float dist = map(pos + normal * len);
    occ += (len - dist) * weight;
    weight *= 0.85;
  }
  return 1.0 - clamp(0.6 * occ, 0.0, 1.0);
}

vec3 lighting(Light lightSource, vec3 rOrigin, vec3 rDirection){
  vec3 L = normalize(lightSource.pos - rOrigin);
  vec3 N = getNormal(rOrigin);
  vec3 V = -rDirection;
  vec3 R = reflect(-L, N);

  vec3 color = lightSource.color;


  // phong lighting
  vec3 specColor = (lightSource.color);
  vec3 specular = 1.3 * specColor * pow(clamp(dot(R, V), 0.0, 1.0), 10.0);
  vec3 diffuse = 0.9 * color * clamp(dot(L, N), 0.0, 1.0);
  vec3 ambient = 0.05 * color;
  vec3 fresnel = 0.15 * color * pow(1.0 + dot(rDirection, N), 3.0);

  // shadows
  //float shadow = softShadow(rOrigin + N * 0.02, lightSource);
  float shadow = softShadow2(rOrigin, L, lightSource.size);

  // occ
  float occ = ambientOcclusion(rOrigin, N);
  
  // back
  vec3 back = 0.05 * color * clamp(dot(N, -L), 0.0, 1.0);

  // final light value
  return  (back + ambient + fresnel) * occ + (specular * occ + diffuse) * shadow;
}


vec3 render(vec2 uv) {
  vec3 color = vec3(0.34, 0.6, 0.94);

  vec3 rOrigin = u_camPos;
  rOrigin = rOrigin / ((u_scroll+1)*0.1);

  vec3 rDirection = normalize(vec3(uv.x-.15, uv.y-.2, 1)); // *BUG* prev: vec3(uv, 1.0);

  // light 1
  Light light1;
  light1.size = 0.05;
  light1.pos = vec3 (5, 5, 0);
  light1.color = vec3(1);

  // light 2
  Light light2;
  light2.size = 0.1;
  light2.pos = vec3 (sin(u_time)*2, 2.0, cos(u_time)*2);
  light2.color = vec3(0.9, 0.0, 0.0);

  float rDist = rayMarch(rOrigin, rDirection, MAX_DIST_TO_TRAVEL);
    
  if (rDist < MAX_DIST_TO_TRAVEL)
  {
    color = vec3(0.0);

    vec3 hitPos = rOrigin + (rDist * rDirection);
    //color += lighting(light1, hitPos, rDirection);
    color += lighting(light2, hitPos, rDirection);
  }

    
  return color;
}

void main() {
  vec2 uv = 2.0 * gl_FragCoord.xy / u_resolution - 1.0;
  // note: properly center the shader in full screen mode
  uv = (2.0 * gl_FragCoord.xy - u_resolution) / u_resolution.y;
  vec3 color = vec3(0.0);
  color = render(uv);
  //color = vec3(uv, 0.0);
  fragColor = vec4(color, 1.0);
}