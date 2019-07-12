#include "Tessellation.cginc"

// These should be defined in the shader, and should include...
//struct vertexInput
//{
//	float4 vertex : POSITION;
//	float3 normal : NORMAL;
//	float4 tangent : TANGENT;
//};
//
//struct vertexOutput
//{
//	float4 vertex : SV_POSITION;
//	float3 normal : NORMAL;
//	float4 tangent : TANGENT;
//};

// Shader Property Accessors
#if TESSELLATION_DISTANCE_ON
	float _TessellationMinDistance = 10.0;
	float _TessellationMaxDistance = 25.0;
#endif

struct TessellationFactors 
{
	float edge[3] : SV_TessFactor;
	float inside : SV_InsideTessFactor;
};

vertexOutput tessVert(vertexInput v)
{
	vertexOutput o;
	// Note that the vertex is NOT transformed to clip
	// space here; this is done in the grass geometry shader.
	o.vertex = v.vertex;
	o.normal = v.normal;
	o.tangent = v.tangent;
	return o;
}

float _TessellationUniform;

TessellationFactors patchConstantFunction (InputPatch<vertexInput, 3> patch)
{
	TessellationFactors f;

	#if TESSELLATION_DISTANCE_ON
		float4 factors = UnityDistanceBasedTess(patch[0].vertex, patch[1].vertex, patch[2].vertex, _TessellationMinDistance, _TessellationMaxDistance, _TessellationUniform);
		f.edge[0] = factors.x;
		f.edge[1] = factors.y;
		f.edge[2] = factors.z;
		f.inside = factors.w;
	#else
		f.edge[0] = _TessellationUniform;
		f.edge[1] = _TessellationUniform;
		f.edge[2] = _TessellationUniform;
		f.inside = _TessellationUniform;
	#endif

	return f;
}

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("integer")]
[UNITY_patchconstantfunc("patchConstantFunction")]
vertexInput hull (InputPatch<vertexInput, 3> patch, uint id : SV_OutputControlPointID)
{
	return patch[id];
}

[UNITY_domain("tri")]
vertexOutput domain(TessellationFactors factors, OutputPatch<vertexInput, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
{
	vertexInput v;

	#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) v.fieldName = \
		patch[0].fieldName * barycentricCoordinates.x + \
		patch[1].fieldName * barycentricCoordinates.y + \
		patch[2].fieldName * barycentricCoordinates.z;

	MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
	MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
	MY_DOMAIN_PROGRAM_INTERPOLATE(tangent)

	return tessVert(v);
}