Shader "GoldShader v3.5 MirrorAvatar"
{
    Properties
    {

        _MainTex("Albedo(RGB)", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        [KeywordEnum(NONE_ON,ZEROPOS_ON)] _Mode("Mode",int) = 0
          
    }
    SubShader
    {
        Pass
        {
            Tags {"LightMode"="ForwardBase"}
        
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #pragma shader_feature _MODE_NONE_ON _MODE_ZEROPOS_ON
            #pragma multi_compile _ LIGHTMAP_ON _MODE_NONE_ON  _MODE_ZEROPOS_ON

            UNITY_DECLARE_TEX2D(_UdonGlobalScreenTexture);
            UNITY_DECLARE_TEX2D(_UdonGlobalScreenMask);

            float4 _MainTex_ST;
            sampler2D _MainTex;
            float4 _Color;

            struct appdata

            {
                float3 pos : POSITION;
                float3 uv1 : TEXCOORD1;
                float3 uv0 : TEXCOORD0;
                float3 normal : NORMAL;
            };

            //Fragment Stuff Variables

            struct v2f
            {
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD2;
                float3 SHCol : COLOR1;
                float UPCol : COLOR2;           
            };

            //Functions List

            //SmoothAround - Function to make directional lights wrap further around the surface of something, simulating indirect

            float SmoothAround (float a)
            {
                return exp(-pow((1 - a)+.5,4));
            }


            //========Vertex Actual Program==========

            v2f vert (appdata INV)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);

                //Set discarded verts to 0
                #ifdef _MODE_ZEROPOS_ON
                        o.pos = float4(0,0,0,0);
                        return o;
                #endif

                //set up vert position
                o.pos = UnityObjectToClipPos(INV.pos);
                
                //world normals (we really only use this for overhead lights)
                half3 worldNormal = UnityObjectToWorldNormal(INV.normal);

                //Pass on UVS
                o.uv0 = INV.uv0.xy;
                o.uv1 = INV.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                
                //Set up world position for overhead lights
                o.worldPos = mul( UNITY_MATRIX_M, float4(INV.pos.xyz,1));
                
                //fake light and falloff from above
                o.UPCol = SmoothAround(dot(worldNormal,float3(0,1,0)));
                
                //Light probe data
                o.SHCol = ShadeSH9(half4(worldNormal,1));

                return o;
            }
            

            //=====Fragment Actual Program=====

            fixed4 frag (v2f INF) : SV_Target
            { 
                //emissive
                #ifdef _MODE_ZEROPOS_ON
                        return float4(0,0,0,0);
                #endif

                //Split Shader Based on Lightmapped / Not             
                #ifdef LIGHTMAP_ON

                    float3 LightMapCol = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap,INF.uv1.xy)) * LIGHTMAP_ON;

                    //Textures

                    float3 MainTextureCol = tex2D(_MainTex,float2(((INF.uv0.x * _MainTex_ST.x) + _MainTex_ST.z),((INF.uv0.y * _MainTex_ST.y) + _MainTex_ST.w)));

                    //R component from probes and maps with floor
                    
                    float3 TexCol = MainTextureCol.rgb * _Color.rgb;
                    
                    float3 col = LightMapCol.rgb * TexCol;

                    //Screen Up calculations for static

                #else

                    //Textures

                    float3 MainTextureCol = tex2D(_MainTex,float2(((INF.uv0.x * _MainTex_ST.x) + _MainTex_ST.z),((INF.uv0.y * _MainTex_ST.y) + _MainTex_ST.w)));

                    //Maintex add

                    float3 TexCol = MainTextureCol.rgb * _Color.rgb;

                    //R component from probes and maps with floor

                    float3 col = INF.SHCol.rgb * TexCol;

                #endif

                return float4(col,1);

            }



        ENDHLSL

        }
    }
}