shader_type sky;

// This shader is inspired by one I found on shadertoy so credit where credit is due:
// https://www.shadertoy.com/view/XtGGRt
// What I've done here is convert it over and adapted it to godot shaders, sky shaders specificly +
// extracted out some customisation variables like setting a color gradient etc +
// made some performance optimisations + overall tried to simplify it a bit.


// equirectangular = flat texture representing a full 360° spherical sky
uniform sampler2D equirectangular_sky_texture : source_color, filter_linear;

uniform sampler2D color_gradient : source_color; // gradient texture 1D
uniform float brightness = 1.7;
uniform float speed = 0.12;
uniform float height = 42.0;
uniform float scale = 0.8;

// The lower the value is for this variable, the better for performance.
// If set too low, the jitter effect on the aurora becomes visible, set it to as low as it can be without it changing the visual effect.
// Could be a uniform but set this variable more mindfully.
const float resolution_loop_count = 30.0; 


mat2 mm2(float a){
    float c = cos(a), s = sin(a);
    return mat2(vec2(c, s), vec2(-s, c));
}

float tri(float x){
    return clamp(abs(fract(x) - 0.5), 0.01, 0.49);
}

vec2 tri2(vec2 p){
    return vec2(tri(p.x) + tri(p.y), tri(p.y + tri(p.x)));
}

float trinoise2d(vec2 p, float t){
    float z = 1.8;
    float z2 = 2.5;
    float rz = 0.0;

    p *= mm2(p.x * 0.06);
    vec2 bp = p;
    mat2 rot = mm2(t);

    for (int i = 0; i < 4; i++) {
        vec2 dg = tri2(bp * 1.85) * 0.75;
        dg = dg * rot;
        p -= dg / z2;

        bp *= 1.3;
        z2 *= 0.45;
        z *= 0.42;

        p *= 1.21 + (rz - 1.0) * 0.02;
        rz += tri(p.x + tri(p.y)) * z;

        p *= mat2(vec2(-0.95534, -0.29552), vec2(0.29552, -0.95534));
    }

    return clamp(1.0 / pow(rz * 29.0, 1.3), 0.0, 0.55);
}


vec4 get_aurora_color(vec3 direction){
    vec4 color = vec4(0.0);
	vec4 average_color = vec4(0.0);
    
	// lower loop count = better performance.
	// instead of using the height as the loop count, jitter is used to decrease loop count and keep a similar visual effect
    float jitter = fract(sin(dot(direction.xz, vec2(13.0, 78.0))));
	float jitter_step_scale = height / resolution_loop_count;
	
    for(int i = 0; i < int(resolution_loop_count); i++) {
        float depth_step = (float(i) + jitter) * jitter_step_scale;
        float depth = ((scale + pow(depth_step, 1.4) * 0.002)) / (direction.y * 2.0 + 0.4);
        vec3 pos = depth * direction;
        float noise = trinoise2d(pos.zx, TIME * speed);

        vec4 col = vec4(0.0);
        col.a = noise;
		
		float weight = exp2(-depth_step * 0.065 - 2.5) * smoothstep(0.0, 5.0, depth_step);
		
        col.rgb = texture(color_gradient, vec2(depth_step / height, 0.0)).rgb * noise;
        average_color = mix(average_color, col, 0.5);
		
        color += average_color * weight * jitter_step_scale;
    }

	color *= clamp(direction.y * 15.0 + 0.4, 0.0, 1.0);
	color *= brightness;
	
    return color;
}


vec3 aurora(vec3 sky_color, vec3 direction) {
	// no need to run calculations on bottom half of the sky to save some performance.
	// -0.1 instead of 0.0 to avoid a hard cutoff of the aurora in the far distance
	bool is_on_top_half_of_sky = direction.y > -0.1;
	
	if(is_on_top_half_of_sky) {
	    vec4 aurora = get_aurora_color(direction);
	    sky_color = mix(sky_color, aurora.rgb, aurora.a);
	}
	return sky_color;
}

vec3 get_base_sky_color_from_sky_texture(vec3 direction) {
    float u = atan(direction.x, direction.z) / (2.0 * PI) + 0.5;
    float v = asin(direction.y) / PI + 0.5; // -asin if it needs to be flipped

	vec3 sky_color = texture(equirectangular_sky_texture, vec2(u, v)).rgb;

	return sky_color;
}

void sky(){
	vec3 direction = normalize(EYEDIR);
	
	vec3 base_sky = get_base_sky_color_from_sky_texture(direction);
	vec3 base_sky_with_aurora = aurora(base_sky, direction);

    COLOR = base_sky_with_aurora;
}
