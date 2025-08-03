// CRT shader, for Godot 4.x
// This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to
// Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
// Adapted from https://www.shadertoy.com/view/4sSGDK
//
// Loosely based on postprocessing shader by inigo quilez, License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// See https://docs.godotengine.org/en/4.1/tutorials/shaders/custom_postprocessing.html for instructions on how to use this shader.
// --------------------------------------------------------------------------------------------------------------------------------------------

shader_type canvas_item;

const vec2 target_resolution = vec2(794, 446);
uniform sampler2D source_texture : repeat_disable, filter_nearest;

uniform bool enabled = true;

group_uniforms Effects;
uniform bool curved_display = true;
uniform bool vignette = true;
uniform bool vlines = true;
uniform bool flicker = true;
uniform bool noise = true;
uniform bool tonemap = true;
uniform bool glow = true;
uniform bool ghosting = true;
uniform bool scanlines = true;
uniform bool level_adjustment = true;
uniform bool wiggle = true;

group_uniforms Effects.BlurType;
uniform bool bleed = true;
uniform bool ntsc = false;
uniform float ntsc_blur_amount : hint_range(0.0, 8.0) = 3.0;
group_uniforms;

uniform float timer_multiplier = 0.1;

vec3 xsample(sampler2D tex, vec2 tc)
{
	vec3 s = pow(texture(tex,vec2(tc.x, tc.y)).rgb, vec3(2.2));
	return s;
}

vec3 filmic(vec3 LinearColor)
{
	vec3 x = max(vec3(0.0), LinearColor - 0.004);
	return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}

vec3 blur(sampler2D tex, vec2 tc, float offs)
{
	vec4 xoffs = offs * vec4(-2.0, -1.0, 1.0, 2.0) / target_resolution.x;
	vec4 yoffs = offs * vec4(-2.0, -1.0, 1.0, 2.0) / target_resolution.y;

	vec3 color = vec3(0.0, 0.0, 0.0);
	color += xsample(tex,tc + vec2(xoffs.x, yoffs.x)) * 0.00366;
	color += xsample(tex,tc + vec2(xoffs.y, yoffs.x)) * 0.01465;
	color += xsample(tex,tc + vec2(    0.0, yoffs.x)) * 0.02564;
	color += xsample(tex,tc + vec2(xoffs.z, yoffs.x)) * 0.01465;
	color += xsample(tex,tc + vec2(xoffs.w, yoffs.x)) * 0.00366;

	color += xsample(tex,tc + vec2(xoffs.x, yoffs.y)) * 0.01465;
	color += xsample(tex,tc + vec2(xoffs.y, yoffs.y)) * 0.05861;
	color += xsample(tex,tc + vec2(    0.0, yoffs.y)) * 0.09524;
	color += xsample(tex,tc + vec2(xoffs.z, yoffs.y)) * 0.05861;
	color += xsample(tex,tc + vec2(xoffs.w, yoffs.y)) * 0.01465;

	color += xsample(tex,tc + vec2(xoffs.x, 0.0)) * 0.02564;
	color += xsample(tex,tc + vec2(xoffs.y, 0.0)) * 0.09524;
	color += xsample(tex,tc + vec2(    0.0, 0.0)) * 0.15018;
	color += xsample(tex,tc + vec2(xoffs.z, 0.0)) * 0.09524;
	color += xsample(tex,tc + vec2(xoffs.w, 0.0)) * 0.02564;

	color += xsample(tex,tc + vec2(xoffs.x, yoffs.z)) * 0.01465;
	color += xsample(tex,tc + vec2(xoffs.y, yoffs.z)) * 0.05861;
	color += xsample(tex,tc + vec2(    0.0, yoffs.z)) * 0.09524;
	color += xsample(tex,tc + vec2(xoffs.z, yoffs.z)) * 0.05861;
	color += xsample(tex,tc + vec2(xoffs.w, yoffs.z)) * 0.01465;

	color += xsample(tex,tc + vec2(xoffs.x, yoffs.w)) * 0.00366;
	color += xsample(tex,tc + vec2(xoffs.y, yoffs.w)) * 0.01465;
	color += xsample(tex,tc + vec2(    0.0, yoffs.w)) * 0.02564;
	color += xsample(tex,tc + vec2(xoffs.z, yoffs.w)) * 0.01465;
	color += xsample(tex,tc + vec2(xoffs.w, yoffs.w)) * 0.00366;

	return color;
}

// Credit: http://stackoverflow.com/questions/4200224/random-noise-functions-for-glsl
float rand(vec2 co)
{
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 curve(vec2 uv)
{
	uv = (uv - 0.5) * 2.0;
	uv *= 1.1;
	uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
	uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
	uv  = (uv / 2.0) + 0.5;
	uv =  uv * 0.92 + 0.04;

	return uv;
}

// START NTSC
vec3 rgb2yiq(vec3 c)
{
	return vec3(
		(0.2989 * c.x + 0.5959 * c.y + 0.2115 * c.z),
		(0.5870 * c.x - 0.2744 * c.y - 0.5229 * c.z),
		(0.1140 * c.x - 0.3216 * c.y + 0.3114 * c.z)
		);
}

vec3 yiq2rgb(vec3 c)
{
	return vec3(
		(1.0 * c.x + 1.0 * c.y + 1.0 * c.z),
		(0.956 * c.x - 0.2720 * c.y - 1.1060 * c.z),
		(0.6210 * c.x - 0.6474 * c.y + 1.7046 * c.z)
		);
}

vec2 circle(float start, float points, float point)
{
	float rad = (3.141592 * 2.0 * (1.0 / points)) * (point + start);
	return vec2(-(0.3 + rad), cos(rad));
}

vec3 blur_ntsc(vec2 uv, float f, float d, float time, sampler2D texture_channel)
{
	float t = (sin(time * 5.0 + uv.y * 5.0)) / 10.0;
	float b = 1.0;

	t = 0.0;
	vec2 pixel_offset = vec2(d + .0005 * t, 0);

	float start = 2.0 / 14.0;
	vec2 scale = 0.66 * ntsc_blur_amount * 2.0 * pixel_offset.xy;

	vec3 N0 = texture(texture_channel, uv + circle(start, 14.0, 0.0) * scale).rgb;
	vec3 N1 = texture(texture_channel, uv + circle(start, 14.0, 1.0) * scale).rgb;
	vec3 N2 = texture(texture_channel, uv + circle(start, 14.0, 2.0) * scale).rgb;
	vec3 N3 = texture(texture_channel, uv + circle(start, 14.0, 3.0) * scale).rgb;
	vec3 N4 = texture(texture_channel, uv + circle(start, 14.0, 4.0) * scale).rgb;
	vec3 N5 = texture(texture_channel, uv + circle(start, 14.0, 5.0) * scale).rgb;
	vec3 N6 = texture(texture_channel, uv + circle(start, 14.0, 6.0) * scale).rgb;
	vec3 N7 = texture(texture_channel, uv + circle(start, 14.0, 7.0) * scale).rgb;
	vec3 N8 = texture(texture_channel, uv + circle(start, 14.0, 8.0) * scale).rgb;
	vec3 N9 = texture(texture_channel, uv + circle(start, 14.0, 9.0) * scale).rgb;
	vec3 N10 = texture(texture_channel, uv + circle(start, 14.0, 10.0) * scale).rgb;
	vec3 N11 = texture(texture_channel, uv + circle(start, 14.0, 11.0) * scale).rgb;
	vec3 N12 = texture(texture_channel, uv + circle(start, 14.0, 12.0) * scale).rgb;
	vec3 N13 = texture(texture_channel, uv + circle(start, 14.0, 13.0) * scale).rgb;
	vec3 N14 = texture(texture_channel, uv).rgb;

	vec4 clr = texture(texture_channel, uv);
	float W = 1.0 / 15.0;

	clr.rgb =
		(N0 * W) +
		(N1 * W) +
		(N2 * W) +
		(N3 * W) +
		(N4 * W) +
		(N5 * W) +
		(N6 * W) +
		(N7 * W) +
		(N8 * W) +
		(N9 * W) +
		(N10 * W) +
		(N11 * W) +
		(N12 * W) +
		(N13 * W) +
		(N14 * W);

	return vec3(clr.xyz) * b;
}
// END NTSC

void fragment()
{
	// Set up variables to be used further along, these primarily provide compatibility with the original codebase and Godot's shader specifics
	float timer = TIME * timer_multiplier;
	vec2 uv = SCREEN_UV.xy;
	vec3 col = texture(source_texture, vec2(uv.x,uv.y)).xyz;

	if (enabled)
	{
		if (curved_display)
		{
			uv = mix(curve(uv), uv, 0.5);
		}

		float x = sin(0.1 * timer + uv.y * 13.0) * sin(0.23 * timer + uv.y * 19.0) * sin(0.3 + 0.11 * timer + uv.y * 23.0) * 0.0012;

		if (!wiggle)
		{
			float o = sin(uv.y * 1.5) / target_resolution.x;
			x += o * 0.25;
			x = 0.0;
		}

		if (bleed)
		{
			col.r = blur(source_texture, vec2(x + uv.x + 0.0009, uv.y + 0.0009), target_resolution.y / 800.0).x + 0.02;
			col.g = blur(source_texture, vec2(x + uv.x + 0.0000, uv.y - 0.0011), target_resolution.y / 800.0).y + 0.02;
			col.b = blur(source_texture, vec2(x + uv.x - 0.0015, uv.y + 0.0000), target_resolution.y / 800.0).z + 0.02;
		}

		if (ntsc)
		{
			float d = 0.1 * 1.0 / 50.0;
			vec2 uv_ntsc = FRAGCOORD.xy / (1.0 / SCREEN_PIXEL_SIZE).xy;

			// Main tearing
			float s = 0.0;
			float e = min(0.30, pow(max(0.0, cos(uv_ntsc.y * 4.0 + 0.3) - 0.75) * (s + 0.5) * 1.0, 3.0)) * 25.0;

			// Apply blur
			d = 0.051 + abs(sin(s / 4.0));
			float c = max(0.0001, 0.002 * d);

			col.xyz = blur_ntsc(uv_ntsc, 0.0, c + c * (uv_ntsc.x), TIME, source_texture);
			float y = rgb2yiq(col.xyz).r;

			uv_ntsc.x += 0.01 * d;
			c *= 6.0;
			col.xyz = blur_ntsc(uv_ntsc, 0.333 ,c, TIME, source_texture);
			float i_ntsc = rgb2yiq(col.xyz).g;

			uv_ntsc.x += 0.005 * d;

			c *= 2.50;
			col.xyz = blur_ntsc(uv_ntsc, 0.666, c, TIME, source_texture);
			float q = rgb2yiq(col.xyz).b;

			col.xyz = yiq2rgb(vec3(y, i_ntsc, q)) - pow(s + e * 2.0, 3.0);
			col.xyz *= smoothstep(1.0, 0.999, uv_ntsc.x - .1);
		}

		float i = clamp(col.r * 0.299 + col.g * 0.587 + col.b * 0.114, 0.0, 1.0);

		// Glow
		if (glow)
		{
			vec3 glow_v = (12.5 * i * i) * pow(clamp(blur(source_texture, vec2(x + uv.x + 0.2 * sin(uv.x + 10.0 * timer) * 0.012, uv.y + 0.2 * sin(uv.y + 7.3 * timer) * 0.012), 4.0) - 0.3, 0.0, 1.0), vec3(5.0));
			glow_v = 0.75 * clamp(glow_v, 0.0, 1.0);
			col += glow_v;
		}

		i = pow(1.0 - pow(i, 2.0), 1.0);
		i = (1.0 - i) * 0.96 + 0.04;

		// Ghosting
		if (ghosting)
		{
			float ghs = 0.6;

			vec3 r = blur(source_texture, vec2(x - 0.014 * 1.0, -0.027) + 0.003 * vec2(0.35 * sin(1.0 / 7.0 + 35.0 * uv.y + 0.9 * timer), 0.55 * sin(2.0 / 7.0 + 10.0 * uv.y + 2.37 * timer)) + vec2(uv.x + 0.001, uv.y + 0.001), 5.5 + 1.3 * sin(3.0 / 9.0 + 31.0 * uv.y + 1.70 * timer)).xyz * vec3(0.5, 0.25, 0.25);
			vec3 g = blur(source_texture, vec2(x - 0.019 * 1.0, -0.020) + 0.003 * vec2(0.35 * sin(1.0 / 9.0 + 35.0 * uv.y + 0.5 * timer), 0.55 * sin(2.0 / 9.0 + 10.0 * uv.y + 2.50 * timer)) + vec2(uv.x + 0.000, uv.y - 0.002), 5.4 + 1.3 * sin(3.0 / 3.0 + 71.0 * uv.y + 1.90 * timer)).xyz * vec3(0.25, 0.5, 0.25);
			vec3 b = blur(source_texture, vec2(x - 0.017 * 1.0, -0.003) + 0.003 * vec2(0.35 * sin(2.0 / 3.0 + 35.0 * uv.y + 0.7 * timer), 0.55 * sin(2.0 / 3.0 + 10.0 * uv.y + 2.63 * timer)) + vec2(uv.x - 0.002, uv.y + 0.000), 5.3 + 1.3 * sin(3.0 / 7.0 + 91.0 * uv.y + 1.65 * timer)).xyz * vec3(0.25, 0.25, 0.5);

			col += vec3(ghs * (1.0 - 0.299)) * pow(clamp(3.0 * r, 0.0, 1.0), vec3(2.0)) * i;
			col += vec3(ghs * (1.0 - 0.587)) * pow(clamp(3.0 * g, 0.0, 1.0), vec3(2.0)) * i;
			col += vec3(ghs * (1.0 - 0.114)) * pow(clamp(3.0 * b, 0.0, 1.0), vec3(2.0)) * i;
		}

		// Level adjustment (curves)
		if (level_adjustment)
		{
			col = clamp(col * 1.7 + 1.4 * col * col + 2.5 * col * col * col * col * col, 0.0, 10.0);
		}

		// Vignette
		if (vignette)
		{
			float vig = (0.1 + 1.0 * 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y));
			vig = 1.0 * pow(vig, 0.5);
			col *= vec3(vig);
		}

		// Scanlines
		if (scanlines)
		{
			float scans = clamp(0.35 + 0.18 * sin(6.0 * timer + uv.y * target_resolution.y * 1.5), 0.0, 1.0);
			float s = pow(scans, 0.9);
			col = col * vec3(s);
		}

		// Vertical lines (aperture)
		if (vlines)
		{
			col *= 1.0 - 0.23 * vec3(clamp((mod(VERTEX.x, 2.0) - 1.0) * 2.0, 0.0, 1.0));
		}

		// Flicker
		if (flicker)
		{
			col *= 1.0 + 0.0017 * sin(300.0 * timer);
		}

		// Noise
		if (noise)
		{
			vec2 seed = floor(uv * target_resolution.xy * 0.5) / target_resolution.xy;
			col *= vec3(1.0) - 0.15 * vec3(rand(seed + 0.00001 * timer), rand(seed + 0.000011 * timer + 0.3), rand(seed + 0.000012 * timer + 0.5));
		}

		// Tone map
		if (tonemap)
		{
			col = filmic(col);
		}

		// Clamp
		if (uv.x < 0.0 || uv.x > 1.0)
			col *= 0.0;
		if (uv.y < 0.0 || uv.y > 1.0)
			col *= 0.0;
	}

	COLOR = vec4(col, 1.0);
}
