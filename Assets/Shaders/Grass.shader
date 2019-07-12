// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/Grass"
{
    Properties
    {
		[Header(Ground)]
    	_Splat0 ("Ground Texture", 2D) = "white" {}
    	_RandomBaseOffset ("RandomBaseOffset", Range(0, 1)) = 0

		[Header(Shading)]
        _TopColor ("Top Color", Color) = (1, 1, 1, 1)
		_BottomColor ("Bottom Color", Color) = (1, 1, 1, 1)
		_TranslucentGain ("Translucent Gain", Range(0, 1)) = 0.5

		[Header(Shape)]
		_BladeWidth ("Blade Width", Float) = 0.05
		_BladeWidthRandom ("Blade Width Random", Float) = 0.02
		_BladeHeight ("Blade Height", Float) = 0.5
		_BladeHeightRandom ("Blade Height Random", Float) = 0.3
		_BladeForward ("Blade Forward Amount", Float) = 0.38
		_BladeCurve ("Blade Curvature Amount", Range(1, 4)) = 2
		_BendRotationRandom ("Bend Rotation Random", Range(0, 1)) = 0.2

		[Header(Tessellation)]
		_TessellationUniform ("Tessellation Uniform", Range(1, 64)) = 1
		_TessellationMinDistance ("Tessellation Min Distance", Float) = 10
		_TessellationMaxDistance ("Tessellation Max Distance", Float) = 25

		[Header(Wind)]
		_WindDistortionMap ("Wind Distortion Map", 2D) = "white" {}
		_WindFrequency ("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
		_WindStrength ("Wind Strength", Float) = 1
    }

	CGINCLUDE
	#include "UnityCG.cginc"
	#include "Autolight.cginc"
	#include "Lighting.cginc"  // FIXME- should this be in the Passes below?

	// constants
	#define BLADE_SEGMENTS 3

	// property accessors
    sampler2D _Splat0;
	float _RandomBaseOffset;
	float _TranslucentGain;
	float _BladeHeight;
	float _BladeHeightRandom;	
	float _BladeWidth;
	float _BladeWidthRandom;
	float _BladeForward;
	float _BladeCurve;
	float _BendRotationRandom;
	sampler2D _WindDistortionMap;
	float4 _WindDistortionMap_ST;
	float2 _WindFrequency;
	float _WindStrength;

	struct geometryOutput
	{
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
		float3 normal : NORMAL;
		unityShadowCoord4 _ShadowCoord : TEXCOORD1;
	};

	struct vertexInput
	{
		float4 vertex : POSITION;
		float2 texcoord : TEXCOORD0;
		float3 normal : NORMAL;
		float4 tangent : TANGENT;
	};

	struct vertexOutput
	{
		float4 vertex : SV_POSITION;
		float2 uv : TEXCOORD0;
		float3 normal : NORMAL;
		float4 tangent : TANGENT;
	};

	geometryOutput VertexOutput(float3 pos, float3 posOffset, float2 uv, float3 normal)
	{
		geometryOutput o;
		o.pos = UnityObjectToClipPos(pos) + float4(posOffset, 0);
		o.uv = uv;
		o.normal = UnityObjectToWorldNormal(normal);
		o._ShadowCoord = ComputeScreenPos(o.pos);
		#if UNITY_PASS_SHADOWCASTER
			// Applying the bias prevents artifacts from appearing on the surface.
			o.pos = UnityApplyLinearShadowBias(o.pos);
		#endif
		return o;
	}

	geometryOutput VertexObjectOutput(vertexOutput IN)
	{
		return VertexOutput(IN.vertex, float3(0, 0, 0), IN.uv, IN.normal);
	}

	geometryOutput GenerateGrassVertex(float3 vertexPosition, float3 posOffset, float width, float height, float forward, float2 uv, float3x3 transformMatrix)
	{
		float3 tangentPoint = float3(width, forward, height);
		float3 tangentNormal = normalize(float3(0, -1, forward));
		float3 localNormal = mul(transformMatrix, tangentNormal);
		float3 localPosition = vertexPosition + mul(transformMatrix, tangentPoint);
		return VertexOutput(localPosition, posOffset, uv, localNormal);
	}

	vertexOutput vert(vertexInput v)
	{
		vertexOutput o;
		o.vertex = v.vertex;
		o.uv = v.texcoord;
		o.normal = v.normal;
		o.tangent = v.tangent;

		// TODO - needed/desired?
//        half3 worldNormal = UnityObjectToWorldNormal(v.normal);
//        half nl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));
//        o.diff = nl * _LightColor0.rgb;
//        o.ambient = ShadeSH9(half4(worldNormal,1));
        // compute shadows data
//        TRANSFER_SHADOW(o)

		return o;
	}

	#include "Includes/Utilities.cginc"
	#include "Includes/TessellationExtensions.cginc"

	[maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
	void geo(triangle vertexOutput IN[3], inout TriangleStream<geometryOutput> triStream)
	{
		// tangent-space axes
		float3 pos = IN[0].vertex;
		float3 vNormal = IN[0].normal;
		float4 vTangent = IN[0].tangent;
		float3 vBinormal = cross(vNormal, vTangent) * vTangent.w;

		// tangent-space transformation matrix
		float3x3 tangentToLocal = float3x3(
			vTangent.x, vBinormal.x, vNormal.x,
			vTangent.y, vBinormal.y, vNormal.y,
			vTangent.z, vBinormal.z, vNormal.z
		);

		// shared random factors
		float3 randomFactors = float3(rand(pos), rand(pos.yzx), rand(pos.zxy));

		// random base offset
		float posOffset = float3(0, 0, 0);
		float3 offset1 = lerp(pos, IN[1].vertex, saturate(randomFactors.x) * _RandomBaseOffset);
		float3 offset2 = lerp(pos, IN[2].vertex, saturate(randomFactors.y) * _RandomBaseOffset);
		pos = lerp(offset1, offset2, saturate(randomFactors.z) * _RandomBaseOffset);

		// random facing transformation matrix  rand(pos)
		float3x3 facingRotationMatrix = AngleAxis3x3(randomFactors.x * UNITY_TWO_PI, float3(0, 0, 1));

		// bending transformation matrix  rand(pos.zzx)
		float3x3 bendRotationMatrix = AngleAxis3x3(randomFactors.x * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));

		// wind
		float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
		float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
		float3 wind = normalize(float3(windSample.x, windSample.y, 0));
		float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);

		// combined transformation matrices
		float3x3 transformationMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix), bendRotationMatrix);
		float3x3 transformationMatrixFacing = mul(tangentToLocal, facingRotationMatrix);

		// build blade of grass in tangent-space  rand(pos.zyx), rand(pos.xzy), rand(pos.yyz)
		float height = (randomFactors.x * 2 - 1) * _BladeHeightRandom + _BladeHeight;
		float width = (randomFactors.y * 2 - 1) * _BladeWidthRandom + _BladeWidth;
		float forward = randomFactors.z * _BladeForward;
		for (int i = 0; i < BLADE_SEGMENTS; i++)
		{
			float t = i / (float)BLADE_SEGMENTS;
			float segmentHeight = height * t;
			float segmentWidth = width * (1 - t);
			float segmentForward = pow(t, _BladeCurve) * forward;
			float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

			triStream.Append(GenerateGrassVertex(pos, posOffset, segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix));
			triStream.Append(GenerateGrassVertex(pos, posOffset, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix));
		}
		triStream.Append(GenerateGrassVertex(pos, posOffset, 0, height, forward, float2(0.5, 1), transformationMatrix));
	}

	[maxvertexcount(BLADE_SEGMENTS * 2 + 4)]
	void geo_shadow(triangle vertexOutput IN[3], inout TriangleStream<geometryOutput> triStream)
	{
		triStream.Append(VertexObjectOutput(IN[0]));
		triStream.Append(VertexObjectOutput(IN[1]));
		triStream.Append(VertexObjectOutput(IN[2]));

		geo(IN, triStream);
	}
	ENDCG

    SubShader
    {
        Pass
        {
			Tags
			{
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
			}

            CGPROGRAM
            #pragma vertex vert0
            #pragma fragment frag0
			#pragma target 3.0
			#pragma multi_compile_fwdbase

			struct v2f
            {
                float2 uv : TEXCOORD0;
                SHADOW_COORDS(1) // put shadows data into TEXCOORD1
                fixed3 diff : COLOR0;
                fixed3 ambient : COLOR1;
                float4 pos : SV_POSITION;
            };

            v2f vert0 (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                half3 worldNormal = UnityObjectToWorldNormal(v.normal);
                half nl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));
                o.diff = nl * _LightColor0.rgb;
                o.ambient = ShadeSH9(half4(worldNormal,1));
                // compute shadows data
                TRANSFER_SHADOW(o)
                return o;
            }

            fixed4 frag0 (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_Splat0, i.uv);
                // compute shadow attenuation (1.0 = fully lit, 0.0 = fully shadowed)
                fixed shadow = SHADOW_ATTENUATION(i);
                // darken light's illumination with shadow, keep ambient intact
                fixed3 lighting = i.diff * shadow + i.ambient;
                col.rgb *= lighting;
                return col;
            }
            ENDCG
        }

        Pass
        {
			Cull Off

			Tags
			{
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
			}

            CGPROGRAM
            #pragma shader_feature _ TESSELLATION_DISTANCE_ON

            #pragma vertex vert
            #pragma hull hull
			#pragma domain domain
			#pragma geometry geo
            #pragma fragment frag
			#pragma target 4.6
			#pragma multi_compile_fwdbase

			float4 _TopColor;
			float4 _BottomColor;

			float4 frag (geometryOutput i, fixed facing : VFACE) : SV_Target
		    {	
				float3 normal = facing > 0 ? i.normal : -i.normal;

				float shadow = SHADOW_ATTENUATION(i);
				float NdotL = saturate(saturate(dot(normal, _WorldSpaceLightPos0)) + _TranslucentGain) * shadow;

				float3 ambient = ShadeSH9(float4(normal, 1));
				float4 lightIntensity = NdotL * _LightColor0 + float4(ambient, 1);
				float4 col = lerp(_BottomColor, _TopColor * lightIntensity, i.uv.y);

				return col;
		    }
            ENDCG
        }

        Pass
		{
			Cull Off

			Tags
			{
				"LightMode" = "ShadowCaster"
			}

			CGPROGRAM
            #pragma shader_feature _ TESSELLATION_DISTANCE_ON

			#pragma vertex vert
			#pragma hull hull
			#pragma domain domain
			#pragma geometry geo_shadow
			#pragma fragment frag
			#pragma target 4.6
			#pragma multi_compile_shadowcaster

			float4 frag(geometryOutput i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}

			ENDCG
		}
    }
}