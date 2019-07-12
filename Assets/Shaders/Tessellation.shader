Shader "Custom/Tessellation"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_TessellationUniform ("Tessellation Uniform", Range(1, 64)) = 1
		_TessellationMinDistance ("Tessellation Min Distance", Float) = 10
		_TessellationMaxDistance ("Tessellation Max Distance", Float) = 25
	}
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma shader_feature _ TESSELLATION_DISTANCE_ON

			#pragma vertex vert
			#pragma fragment frag
			#pragma hull hull
			#pragma domain custom_domain
			#pragma target 4.6
			
			#include "UnityCG.cginc"

			struct vertexInput
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};
			
			struct vertexOutput
			{
				float4 vertex : SV_POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			vertexInput vert(vertexInput v)
			{
				return v;
			}

			#include "Includes/TessellationExtensions.cginc"

			// Define custom vertex and domain shaders that transform the 
			// outputted vertex to clip space; in the CustomTessellation file,
			// this transformation is not performed, as it is executed later
			// in our grass geometry shader.
			vertexOutput tessVertTransformed(vertexInput v)
			{
				vertexOutput o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.normal = v.normal;
				o.tangent = v.tangent;
				return o;
			}

			[UNITY_domain("tri")]
			vertexOutput custom_domain(TessellationFactors factors, OutputPatch<vertexInput, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
			{
				vertexInput v;

				#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) v.fieldName = \
					patch[0].fieldName * barycentricCoordinates.x + \
					patch[1].fieldName * barycentricCoordinates.y + \
					patch[2].fieldName * barycentricCoordinates.z;

				MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
				MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
				MY_DOMAIN_PROGRAM_INTERPOLATE(tangent)

				return tessVertTransformed(v);
			}

			float4 _Color;
			
			float4 frag (vertexOutput i) : SV_Target
			{
				return _Color;
			}
			ENDCG
		}
	}
}
