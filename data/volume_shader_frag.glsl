#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D texture;
varying vec4 vertColor;
varying vec4 vertTexCoord;

uniform vec3 lightPos;
varying vec3 ecNormal;
varying vec4 ecVertex;


void main() {
  gl_FragColor = texture2D(texture, vertTexCoord.st) * vertColor;

#if 0
  bool front = dot(lightPos - ecNormal, ecNormal) > 0.0;
  gl_FragColor = front ? vec4(0.0, 1.0, 0.0, 1.0) : vec4(1.0, 0.0, 0.0, 1.0);
#else
  gl_FragColor = gl_FrontFacing ? vec4(0.0, 1.0, 0.0, 1.0) : vec4(1.0, 0.0, 0.0, 1.0);
#endif
}
