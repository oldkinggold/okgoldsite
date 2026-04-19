Shader "GoldShader v8 (identica 2) Avatar"
{
    Properties

    {

        _MainTex("Albedo(RGB)", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        _BumpMap("Normal Map", 2D) = "bump" {}
        _MochieMetallicMaps("Packed Spec", 2D) = "white" {}
        _Metallic("Metallic", Range(0.0, 1.0)) = 0
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0

        [KeywordEnum(NONE_ON,ZEROPOS_ON)] _Mode("Mode",int) = 0

    }

    SubShader

    {
        

            Tags
            {
                "RenderType"="Opaque"
                "Queue"="Geometry"
            }
            
            LOD 100

        Pass
        {         
            Tags 
            {
                "LightMode"="ForwardBase"
            }

            Cull Back
            ZWrite On
            ZTest LEqual
            Blend Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #pragma multi_compile_instancing
            #pragma shader_feature _MODE_NONE_ON _MODE_ZEROPOS_ON
            #pragma multi_compile LIGHTMAP_ON _MODE_NONE_ON _MODE_ZEROPOS_ON

            UNITY_DECLARE_TEX2D(_UdonGlobalScreenTexture);
            UNITY_DECLARE_TEX2D(_UdonGlobalScreenMask);

            float4 _MainTex_ST;
            sampler2D _MainTex;
            float4 _BumpMap_ST;
            sampler2D _BumpMap;
            float4 _Color;
            float _Smoothness;
            float _Metallic;
            sampler2D _MochieMetallicMaps;

            struct appdata
            {
                float4 pos : POSITION;
                float2 uv1 : TEXCOORD1;
                float2 uv0 : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                
                UNITY_VERTEX_INPUT_INSTANCE_ID

            };

            //Fragment Stuff Variables

            struct v2f
            {
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD2;
                float3 tangent : TEXCOORD3;
                float3 bitangent : TEXCOORD4;
                float3 normal : TEXCOORD5;
                float3 worldRefl : TEXCOORD6;
                float3 worldViewDir : TEXCOORD7;
                half UPCol : COLOR2;      
                UNITY_VERTEX_OUTPUT_STEREO
     
            };

            //Functions List

            //SmoothAround - Function to make directional lights wrap further around the surface of something, simulating indirect

            half SmoothAround (half a)
            {
                return exp(-pow((1 - a)+.5,4));
            }


            //========Vertex Actual Program==========

            v2f vert (appdata INV)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_SETUP_INSTANCE_ID(INV);

                //Set discarded verts to 0

                #ifdef _MODE_ZEROPOS_ON
                        o.pos = float4(0,0,0,0);
                        return o;
                #endif
                
                //world normals (we really only use this for overhead lights)

                o.normal = UnityObjectToWorldNormal(INV.normal);

                o.pos = UnityObjectToClipPos(INV.pos);

                //Pass on UVS
                o.uv0 = INV.uv0.xy;
                o.uv1 = INV.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                
                //Set up world position for overhead lights
                o.worldPos = mul( UNITY_MATRIX_M, float4(INV.pos.xyz,1));
                
                //fake light and falloff from above
                o.UPCol = SmoothAround(dot(o.normal,float3(0,1,0)));

                //this stuff is for normal maps
                o.tangent = UnityObjectToWorldDir( INV.tangent.xyz );
                o.bitangent = cross(o.normal,o.tangent) * (INV.tangent.w) * unity_WorldTransformParams.w;

                //this stuff is for reflections
                o.worldViewDir = normalize(UnityWorldSpaceViewDir(o.worldPos));

                return o;
            }
            

            //=====Fragment Actual Program=====

            fixed4 frag (v2f INF) : SV_Target
            { 

                //Discard

                #ifdef _MODE_ZEROPOS_ON
                        return float4(0,0,0,0);
                #endif 

                //decide smoothness and metal
                
                float4 PackedSpecCol = saturate(tex2D(_MochieMetallicMaps,INF.uv0)*4);

                float FragSmooth = max((max(_Smoothness,0)),0) * PackedSpecCol.r * PackedSpecCol.b * PackedSpecCol.a ;

                float FragMetal = max(_Metallic,0) * PackedSpecCol.g * PackedSpecCol.b * PackedSpecCol.a;

                //LampEmm

                float3 HouseLightsMultR = UNITY_SAMPLE_TEX2D(_UdonGlobalScreenTexture, float2((0.9375),(0.046875))).rgb;
                float3 LightAMultG = UNITY_SAMPLE_TEX2D(_UdonGlobalScreenTexture, float2((0.9375),(0.15625))).rgb;
                float3 LightBMultB = UNITY_SAMPLE_TEX2D(_UdonGlobalScreenTexture, float2((0.9375),(0.265625))).rgb;

                //normal stuff

                float3 tangentSpaceNormal = float4(UnpackNormal( tex2D(_BumpMap,float2(((INF.uv0.x * _BumpMap_ST.x) + _BumpMap_ST.z),((INF.uv0.y * _BumpMap_ST.y) + _BumpMap_ST.w)))),1);
                float3x3 mtxTangToWorld = {
                     INF.tangent.x, INF.bitangent.x , INF.normal.x,
                     INF.tangent.y, INF.bitangent.y , INF.normal.y,
                     INF.tangent.z, INF.bitangent.z , INF.normal.z,  
                };    

                float3 NormalFinal = mul( mtxTangToWorld, tangentSpaceNormal);

                //SH Col declared early

                float3 SHCol = float3(0,0,0);

                //UPCol Replacement

                float3 UPCol = SmoothAround(dot(NormalFinal,float3(0,1,0)));

                //Smooth stuff

                half3 worldRefl = reflect(-INF.worldViewDir, NormalFinal);
                
                half mip = (1-FragSmooth)*5;
                half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0,worldRefl,mip);
                half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR);
                half3 fresnel = pow(1-(saturate(dot(INF.worldViewDir,NormalFinal))),(1 + FragSmooth*3));

                //Split Shader Based on Lightmapped / Not             
                    //SH Color

                    SHCol = ShadeSH9(float4(NormalFinal,1));

                    //Textures

                    float3 MainTextureCol = tex2D(_MainTex,float2(((INF.uv0.x * _MainTex_ST.x) + _MainTex_ST.z),((INF.uv0.y * _MainTex_ST.y) + _MainTex_ST.w)));

                    float3 TexCol = saturate(MainTextureCol.rgb) * saturate(_Color.rgb);

                   float3 col = SHCol * TexCol;

                //color stuff

                float3 tc = col / (col + 1.0);
                float3 lum = dot(col, float3(0.2126729f,  0.7151522f, 0.0721750f));
                float3 coltone = (lerp(col / (lum + 1.0), tc, tc)) * (1-FragMetal);

                coltone += ((FragMetal) * skyColor * TexCol) + (skyColor * max(fresnel,float(0.1)) * FragSmooth);
                
                return float4((coltone),1);
                //return float4(coltone,1);            

            }

        ENDHLSL

        }
    }
    
    FallBack Off

}