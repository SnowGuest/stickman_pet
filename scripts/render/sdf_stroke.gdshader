shader_type canvas_item;
render_mode unshaded;

uniform vec4 stroke_color : source_color = vec4(1.0, 0.4, 0.0, 1.0);
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform vec4 seg0;
uniform vec4 seg1;
uniform vec4 seg2;
uniform vec4 seg3;
uniform vec4 seg4;
uniform vec4 seg5;
uniform vec4 seg6;
uniform vec4 seg7;
uniform vec4 seg8;
uniform vec4 seg9;
uniform vec4 seg10;
uniform vec4 seg11;
uniform vec4 seg12;
uniform vec4 seg13;
uniform vec4 seg14;
uniform vec4 seg15;
uniform vec4 seg16;
uniform vec4 seg17;
uniform vec4 seg18;
uniform vec4 seg19;
uniform vec4 seg20;
uniform float line_radius = 5.0;
uniform vec2 head_center = vec2(-1000.0);
uniform float head_radius = 18.0;
uniform float head_half_width = 3.0;
uniform bool head_hollow = true;

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ba = b - a;
	float len2 = max(dot(ba, ba), 1e-5);
	float h = clamp(dot(p - a, ba) / len2, 0.0, 1.0);
	return length(p - (a + ba * h));
}

void fragment() {
	vec2 p = UV * screen_size;
	float d = segment_distance(p, seg0.xy, seg0.zw);
	d = min(d, segment_distance(p, seg1.xy, seg1.zw));
	d = min(d, segment_distance(p, seg2.xy, seg2.zw));
	d = min(d, segment_distance(p, seg3.xy, seg3.zw));
	d = min(d, segment_distance(p, seg4.xy, seg4.zw));
	d = min(d, segment_distance(p, seg5.xy, seg5.zw));
	d = min(d, segment_distance(p, seg6.xy, seg6.zw));
	d = min(d, segment_distance(p, seg7.xy, seg7.zw));
	d = min(d, segment_distance(p, seg8.xy, seg8.zw));
	d = min(d, segment_distance(p, seg9.xy, seg9.zw));
	d = min(d, segment_distance(p, seg10.xy, seg10.zw));
	d = min(d, segment_distance(p, seg11.xy, seg11.zw));
	d = min(d, segment_distance(p, seg12.xy, seg12.zw));
	d = min(d, segment_distance(p, seg13.xy, seg13.zw));
	d = min(d, segment_distance(p, seg14.xy, seg14.zw));
	d = min(d, segment_distance(p, seg15.xy, seg15.zw));
	d = min(d, segment_distance(p, seg16.xy, seg16.zw));
	d = min(d, segment_distance(p, seg17.xy, seg17.zw));
	d = min(d, segment_distance(p, seg18.xy, seg18.zw));
	d = min(d, segment_distance(p, seg19.xy, seg19.zw));
	d = min(d, segment_distance(p, seg20.xy, seg20.zw));
	float body = 1.0 - smoothstep(line_radius - 1.0, line_radius + 0.75, d);
	float head_alpha = 0.0;
	float head_d = distance(p, head_center);
	if (head_hollow) {
		float ring_d = abs(head_d - head_radius);
		head_alpha = 1.0 - smoothstep(head_half_width - 1.0,
				head_half_width + 0.75, ring_d);
	} else if (head_d < head_radius) {
		head_alpha = 1.0;
	}
	float alpha = max(body, head_alpha);
	if (head_hollow && head_d < head_radius - head_half_width) {
		alpha = 0.0;
	}
	COLOR = vec4(stroke_color.rgb, stroke_color.a * alpha);
}
