shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D bent_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm : filter_linear_mipmap_anisotropic;

uniform bool flip_normal_y = true; // Unreal uses DirectX (+Y Down) normals
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform float roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_scale : hint_range(0.0, 2.0) = 1.0;
uniform float ao_amount : hint_range(0.0, 1.0) = 1.0;
uniform float anisotropy : hint_range(-1.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5; // UE default 0.5 specular (4% base reflectivity)

void fragment() {
	vec4 alb = texture(albedo, UV);
	vec3 norm_raw = texture(normal, UV).rgb;
	vec3 bnorm_raw = texture(bent_normal, UV).rgb;
	vec3 orm_tex = texture(orm, UV).rgb;

	// Invert Green channel if using textures exported for Unreal Engine (DirectX format)
	if (flip_normal_y) {
		norm_raw.g = 1.0 - norm_raw.g;
		bnorm_raw.g = 1.0 - bnorm_raw.g;
	}

	ALBEDO = alb.rgb;
	NORMAL_MAP = norm_raw;
	NORMAL_MAP_DEPTH = normal_scale;
	BENT_NORMAL_MAP = bnorm_raw;
	
	// Unreal ORM channel packing: R = AO, G = Roughness, B = Metallic
	AO = clamp(orm_tex.r * ao_amount, 0.0, 1.0);
	AO_LIGHT_AFFECT = ao_amount;
	ROUGHNESS = clamp(orm_tex.g * roughness_scale, 0.0, 1.0);
	METALLIC = clamp(orm_tex.b * metallic_scale, 0.0, 1.0);
	ANISOTROPY = anisotropy;
	SPECULAR = specular;
}