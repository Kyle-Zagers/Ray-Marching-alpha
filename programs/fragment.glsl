#version 330 core
#include hg_sdf.glsl

layout (location = 0) out vec4 fragColor;

precision mediump float;

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;
uniform float u_scroll;
//uniform int u_key;
//uniform vec3 u_camPos;

const float MAX_STEPS = 100.0;
const float MIN_DIST_TO_SDF = 0.001;
const float MAX_DIST_TO_TRAVEL = 100.0;
const float EPSILON = 0.001;









vec2 calcSDF(vec3 pos) {
    float matID = 0.0; //temporary default

    float planeDist = fPlane(pos, vec3(0.0, 1.0, 0.0), 1.0);
    float boxDist = fBox(pos-vec3(0, 0.5, 0), vec3(0.5));

    float dist = min(planeDist, boxDist);

    return vec2(dist, matID);
}


float calcAO(vec3 pos, vec3 normal) {
    float occ = 0.0;
    float sca = 1.0;

    for(int i=0; i<5; i++) {
        float hrconst = 0.03; // larger values = AO
        float hr = hrconst + 0.15*float(i)/4.0;
        vec3 aopos =  normal * hr + pos;
        float dd = calcSDF( aopos ).x;
        occ += (hr-dd)*sca;
        sca *= 0.95;
    }
    return clamp(1.0 - occ*1.5, 0.0, 1.0);
}


// cut1 and cut2 define the center cone and the max width of the light
// they are cosines of the corresponding angles, so a center cone of
// 15 degrees and a max width of 30 degrees would correspond to
// cut1 = 0.9659258 and cut2 = 0.8660254
// lr is the normalized light ray
float calcDirLight(vec3 p, vec3 lookfrom, vec3 lookat,
                           in float cut1, in float cut2) {
    vec3 lr = normalize(lookfrom - p);
    float intensity = dot(lr, normalize(lookfrom - lookat));
    return smoothstep(cut2, cut1, intensity);
}


// https://iquilezles.org/articles/rmshadows
float calcSoftshadow(in vec3 ro, in vec3 rd, in float mint, in float tmax)
{
	float t = mint;
    float k = 20.;  // "softness" of shadow. smaller numbers = softer

    // unroll first loop iteration
    float h = calcSDF(ro + rd*t).x;
    float res = min(1., k*h/t);
    t += h;
    float ph = h; // previous h
    
    for( int i=1; i<60; i++ )
    {
        if( res<0.01 || t>tmax ) break;        

        h = calcSDF(ro + rd*t).x;
        float y = h*h/(2.0*ph);
        float d = sqrt(h*h-y*y);
        res = min(res, k*d/max(0.0, t-y));
        ph = h;
        t += h;
    }
    res = clamp( res, 0.0, 1.0 );
    return res*res*(3.0-2.0*res);  // smoothstep, smoothly transition from 0 to 1
}


vec3 calcLight(vec3 pos, vec3 normal, vec3 rDirRef, float ambientOcc, vec3 material, float kSpecular) {
    float kDiffuse = 0.4,
        kAmbient = 0.2;

    vec3 col_light = vec3(1.0),
        iSpecular = 6.*col_light,  // intensity
        iDiffuse = 2.*col_light,
        iAmbient = 1.*col_light;
    
    vec3 lPos = vec3(5.*cos(-u_time), 4, 5.*sin(-u_time)); // light position
    vec3 lDir = vec3(0.5, 0.0, 0.0);

    float alpha_phong = 20.0; // phong alpha component


    vec3 lRay = normalize(lPos - pos);
    
    float light = calcDirLight(pos, lPos, lDir, 0.96, 0.86);
    vec3 lDirRef = reflect(lRay, normal);

    float shadow = 1.0;
    if (light > 0.001) { // no need to calculate shadow if we're in the dark
        shadow = calcSoftshadow(pos, lRay, 0.01, 20.0);
    }
    vec3 dif = light*kDiffuse*iDiffuse*max(dot(lRay, normal), 0.)*shadow;
    vec3 spec = light*kSpecular*iSpecular*pow(max(dot(lRay, rDirRef), 0.), alpha_phong)*shadow;
    vec3 amb = light*kAmbient*iAmbient*ambientOcc;

    return material*(amb + dif + spec);
    
}


vec4 getNormal(vec3 pos) { 
    vec2 dist = calcSDF(pos);
    vec2 e = vec2(EPSILON, 0.0);

    vec3 normal = dist.x - vec3(
        calcSDF(pos-e.xyy).x,
        calcSDF(pos-e.yxy).x,
        calcSDF(pos-e.yyx).x);

    return vec4(normalize(normal), dist.y);
}

vec3 getNormal2(vec3 p) {
    vec2 e = vec2(EPSILON, 0.0);
    vec3 n = vec3(calcSDF(p).x) - vec3(calcSDF(p - e.xyy).x, calcSDF(p - e.yxy).x, calcSDF(p - e.yyx).x);
    return normalize(n);
}

vec3 getNormal3(vec3 pos) { 
    vec2 dist = calcSDF(pos);
    vec2 e = vec2(EPSILON, 0.0);

    vec3 normal = dist.x - vec3(
        calcSDF(pos-e.xyy).x,
        calcSDF(pos-e.yxy).x,
        calcSDF(pos-e.yyx).x);

    return normalize(normal);
}


float rMarch(vec3 rOrig, vec3 rDir) {
    float dOrig = 0.0; // distance from ray origin

    for(int i=0; i<MAX_STEPS; i++) {
        vec3 rPos = rOrig + rDir * dOrig;
        float dSurf = calcSDF(rPos).x;
        dOrig += dSurf;
        if(dOrig > MAX_DIST_TO_TRAVEL || abs(dSurf) < MIN_DIST_TO_SDF) break;
    }

    return dOrig;
}


vec3 render(vec3 rOrig, vec3 rDir) {
    vec3 col = vec3(0);

    float dist = rMarch(rOrig, rDir);

    if (dist<MAX_DIST_TO_TRAVEL) {
        vec3 pos = rOrig + rDir * dist; // surface point location
        vec4 normalVal = getNormal(pos);
        vec3 normal = normalVal.xyz; //surface normal
        vec3 rDirRef = reflect(rDir, normal); // reflected ray
        //float matID = normalVal.w;

        float ambientOcc = calcAO(pos, normal);

        col += calcLight(pos, normal, rDirRef, ambientOcc, vec3(1.0, 1.0, 1.0), 0.5);
        //col = normal;
    }
    return clamp(col, 0.0, 1.0);
}


// Camera system explained here:
// https://www.youtube.com/watch?v=PBxuVlp7nuM
vec3 rDir(vec2 uv, vec3 rOrig, vec3 lookat, float zoom) {
    vec3 forward = normalize(lookat-rOrig),
        right = normalize(cross(forward, vec3(0, 1., 0))),
        up = cross(right, forward),
        center = forward*zoom,
        intersection = center + uv.x*right + uv.y*up,
        dir = normalize(intersection);
    return dir;
}


mat2 rotMatrix(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}


void main() {
    vec2 uv = (gl_FragCoord.xy-.5*u_resolution.xy)/u_resolution.y;
	vec2 mouse = u_mouse.xy/u_resolution.xy;

    if (mouse.x != 0. || mouse.y != 0.) {
        mouse -= vec2(.5, .5);
    }
    mouse.y = clamp(mouse.y, -.3, .15);


    vec3 rOrig = vec3(-4, 3, 20);
    rOrig.yz *= rotMatrix(mouse.y*3.14);
    rOrig.xz *= rotMatrix(mouse.x*2.*3.14);
    
    vec3 rDir = rDir(uv, rOrig, vec3(0., 1.0, 0.), 2.3);
    
    vec3 col = render(rOrig, rDir);
    //col = vec3(uv,0.0);
    
    // col = pow(col, vec3(.4545));	// gamma correction
    
    fragColor = vec4(col,1.0); 
}
