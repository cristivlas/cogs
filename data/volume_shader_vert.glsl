#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform mat4 modelview;
uniform mat4 projection;
uniform mat4 texMatrix;
uniform mat3 normalMatrix;

attribute vec3 normal;
attribute vec4 vertex;
attribute vec4 color;
attribute vec2 texCoord;

varying vec4 vertColor;
varying vec4 vertTexCoord;
varying vec4 ecVertex;
varying vec3 ecNormal;

uniform vec3 lightPos;  // model coords
uniform mat4 shadowProjection;


void main() {
  vertColor = color;
  vertTexCoord = texMatrix * vec4(texCoord, 1.0, 1.0);
  ecNormal = normalMatrix * normal;
  ecVertex = modelview * vertex;

  vec3 p = vec3(ecVertex); 
  vec3 lightDir = normalize(lightPos - p);
  
  if (dot(ecNormal, lightDir) < 0.0) {
    vec4 v = vec4(-lightDir, 0.0);
    gl_Position = shadowProjection * v;
  }
  else { 
    gl_Position = projection * ecVertex;
  }
}

