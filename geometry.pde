import java.util.Collections;

static float LOOKUP_PRECISION = 0.0001;
static float SINCOS_PRECISION = 0.0001;

static float ROUND(float x, float prec) {
  assert !Float.isNaN(x);
  int scale = (int) (1.0 / prec);
  float result = Math.round(x * scale + 0.5 * prec) / (float)scale;
  assert EQUAL(x, result, prec);
  return result;
}
static float ROUND(float x) {
  return ROUND(x, LOOKUP_PRECISION);  
}
static boolean EQUAL(float a, float b, float prec) {
  return Math.abs(a - b) < prec;
}
static boolean EQUAL(float a, float b) {
  return EQUAL(a, b, LOOKUP_PRECISION);
}
static boolean EQUAL(PVector v1, PVector v2) {
  return EQUAL(v1.x, v2.x) && EQUAL(v1.y, v2.y) && EQUAL(v1.z, v2.z);
}
static float COS(float x) {
  float result = cos(x);
  return ROUND(result, SINCOS_PRECISION);
}
static float SIN(float x) {
  float result = sin(x);
  return ROUND(result, SINCOS_PRECISION);
}

//
// Construct shapes with hidden edges that get extruded by the shadow volume shader. 
//
class Geometry {
  static final color FILL_COLOR = 150;
  
  Geometry(boolean shadow /* include edges for shadow volume extrusion? */) {
    this.shadow = shadow;
    shape.beginShape(QUADS);
    shape.noStroke();
    shape.fill(FILL_COLOR);
  }
  PShape getShape() {
    assert edge == null : edge;
    if (open) {
      // println(this, edges.size(), "edges left (", edgeCount, "total )", vfaces.size(), "vfaces");
      if (shadow) {
        if (!edges.isEmpty()) g.showWarning("Geometry not properly closed");
        for (VFace f : vfaces) f.add();
      }
      shape.endShape();
      open = false;
    }
    return shape;
  }
  void normal(float nx, float ny, float nz) {
    shape.normal(nx, ny, nz);
  }
  void texture(PImage img) {
    if (img != null) {
      hasTexture = true;
      shape.texture(img);
    }
  }
  void vertex(float x, float y, float z) {    
    vertex(x, y, z, 0, 0);
  }
  void vertex(float x, float y, float z, float u, float v) {
    quadVertices.add(new Vertex(x, y, z, u, v));
    assert quadVertices.size() <= 4 : quadVertices.size(); 
    if (quadVertices.size() == 4) {
      if (invertWinding) Collections.reverse(quadVertices);
      // compute normal
      PVector a = quadVertices.get(0);
      PVector b = quadVertices.get(1).get();
      PVector c = quadVertices.get(2).get();
      b.sub(a);
      c.sub(a);
      a = b.cross(c);
      a.normalize();
      normal(a.x, a.y, a.z);
      for (Vertex vert : quadVertices) {
        vertexImpl(vert.x, vert.y, vert.z, vert.u, vert.v);
        ++vertexCount;
      }
      assert vertexCount % 4 == 0 : vertexCount;
      closeFace();
      quadVertices.clear();
    }
  }    
  private void addEdge() {
    PVector v = shape.getVertex(shape.getVertexCount() - 1);
    addEdge(v, false);
  }
  private void addEdge(PVector v, boolean close) {
    assert !close || edge != null : edge;
    if (edge != null) {
      edge.v2 = v;
//      Edge other = edges.get(edge);
//      assert edge != other;
//      if (other == null) {
//        edges.put(edge, edge);
//      } 
//      else {
//        vfaces.add(new VFace(edge, other));
//        edges.remove(edge);
//      }
      int i = edges.indexOf(edge);
      if (i < 0) {
        edges.add(edge);
      } 
      else {
        Edge other = edges.get(i);
        assert edge != other;
        vfaces.add(new VFace(edge, other));
        edges.remove(i);
      }
    }
    if (!close) {
      edge = new Edge();
      edge.v1 = v;
      edge.index = shape.getVertexCount() - 1;
    }
    ++edgeCount;
  }
  private void closeFace() {
    if (vertexCount % 4 == 0) {
      PVector v = shape.getVertex(shape.getVertexCount() - 4);
      addEdge(v, true);
      edge = null;
    }
  }
  private void vertexImpl(float x, float y, float z) {
    assert open;
    shape.vertex(x, y, z);
    addEdge();
  }
  private void vertexImpl(float x, float y, float z, float u, float v) {
    assert open;
    if (hasTexture) shape.vertex(x, y, z, u, v);
    else shape.vertex(x, y, z);
    addEdge();
  }
  private class Edge {
    PVector v1, v2;
    int index;
    boolean equals(Object obj) {
      Edge other = (Edge) obj;
      // when faces have correct winding the other edge has the vertices reversed
      return /* (EQUAL(v1, other.v1) && EQUAL(v2, other.v2)) ||*/ (EQUAL(v1, other.v2) && EQUAL(v2, other.v1));
    }
    int hashCode() {      
      int result = 1;
      result += 31 * Float.floatToIntBits(ROUND(v1.x + v2.x));
      result += 31 * Float.floatToIntBits(ROUND(v1.y + v2.y));
      result += 31 * Float.floatToIntBits(ROUND(v1.z + v2.z));
      return result;
    }
    String toString() {
      return super.toString() + " (" + v1 + v2 + ")";
    }
  }
  private class Vertex extends PVector {
    Vertex(float x, float y, float z, float u, float v) {
      super(x, y, z);
      this.u = u;
      this.v = v;
    }
    final float u, v;
  }
  private class VFace { // "virtual" face -- for extrusion purposes
    VFace(Edge e1, Edge e2) {
      assert e1.equals(e2);
      v1 = e1.v1;
      v2 = e1.v2;
      n1 = shape.getNormal(e1.index);
      n2 = shape.getNormal(e2.index);
    }
    void add() {
      if (n1.dot(n2) == 1.0) return;
      shape.normal(n1.x, n1.y, n1.z);
      shape.vertex(v2.x, v2.y, v2.z, 0, 0);
      shape.vertex(v1.x, v1.y, v1.z, 0, 0);
      shape.normal(n2.x, n2.y, n2.z);
      shape.vertex(v1.x, v1.y, v1.z, 0, 0);
      shape.vertex(v2.x, v2.y, v2.z, 0, 0);
    }  
    PVector v1, v2, n1, n2;
  }
  final boolean shadow;
  boolean open = true;
  PShape shape = createShape(PShape.GEOMETRY);
//  HashMap<Edge, Edge> edges = new HashMap();
  ArrayList<Edge> edges = new ArrayList();
  ArrayList<Vertex> quadVertices = new ArrayList();
  ArrayList<VFace> vfaces = new ArrayList();
  int edgeCount = 0, vertexCount = 0;
  Edge edge;
  boolean hasTexture = false, invertWinding = false; // for delayed mode
}


PShape makeBox(float w, float h, float d, PImage tex, boolean shadow) {
  Geometry geom = new Geometry(shadow);
  geom.invertWinding = true;
  float tw = 0, th = 0;
  if (tex != null) {
    geom.texture(tex);
    tw = tex.width;
    th = tex.height;
  }
  // bottom
  geom.vertex(0, h, 0, 0, 0);
  geom.vertex(w, h, 0, tw, 0);
  geom.vertex(w, h, -d, tw, th);
  geom.vertex(0, h, -d, 0, th);
  // back
  geom.vertex(w, 0, -d, 0, 0);
  geom.vertex(0, 0, -d, tw, 0);
  geom.vertex(0, h, -d, tw, th);
  geom.vertex(w, h, -d, 0, th);
  // left
  geom.vertex(0, 0, -d, 0, 0);
  geom.vertex(0, 0, 0, tw, 0);
  geom.vertex(0, h, 0, tw, th);
  geom.vertex(0, h, -d, 0, th);
  // right
  geom.vertex(w, 0, 0, 0, 0);
  geom.vertex(w, 0, -d, tw, 0);
  geom.vertex(w, h, -d, tw, th);
  geom.vertex(w, h, 0, 0, th);
  // top
  geom.vertex(0, 0, -d, 0, 0);
  geom.vertex(w, 0, -d, tw, 0);
  geom.vertex(w, 0, 0, tw, th);
  geom.vertex(0, 0, 0, 0, th);
  // front
  geom.vertex(0, 0, 0, 0, 0);
  geom.vertex(w, 0, 0, tw, 0);
  geom.vertex(w, h, 0, tw, th);
  geom.vertex(0, h, 0, 0, th);
  // center it
  geom.getShape().translate(-w/2, -h/2, d/2);
  return geom.getShape();
}


PShape makeCone(float rBase, float rTop, float h, PImage tex, int nSides, float slope, boolean shadow) {
  if (rTop == 0) rTop = 1;
  final int nSections = round(h / (TWO_PI * rBase) + 0.5); 
  final float hSection = h / nSections;
  float x[] = new float[nSides + 1];
  float z[] = new float[nSides + 1];
  float r[] = new float[nSections + 1];
  float s[] = new float[nSections + 1];
  for (int i = 0; i != x.length; ++i) {
    float angle = TWO_PI / nSides * i;
    z[i] = SIN(angle);
    x[i] = COS(angle);
  }
  for (int i = 0; i != s.length; ++i) {
    float hi = h - i * hSection;
    r[i] = (rBase * (h - hi) + rTop * hi) / h;
    s[i] = slope * hi;
  }
  Geometry geom = new Geometry(shadow);
  float tw = 0, th = 0, wTex = 0, hTex = 0;
  if (tex != null) {
    geom.texture(tex);
    wTex = tex.width;
    hTex = tex.height;
    tw = wTex / nSides;    // tile width
    th = hTex / nSections; // tile height
  }
  for (int n = 0; n != nSections; ++n) {
    float y = n * hSection - h/2;
    for (int i = 1; i != x.length; ++i) {
      geom.vertex(s[n+1] + r[n+1] * x[i-1], y + hSection, r[n+1] * z[i-1], (i-1) * tw, th * (n + 1));
      geom.vertex(s[n]   + r[n]   * x[i-1], y,            r[n]   * z[i-1], (i-1) * tw, th * n);
      geom.vertex(s[n]   + r[n]   * x[i],   y,            r[n]   * z[i],   i * tw,     th * n);
      geom.vertex(s[n+1] + r[n+1] * x[i],   y + hSection, r[n+1] * z[i],   i * tw,     th * (n + 1));
    }
  }
  for (int i = 1; i != x.length; ++i) { // top
    geom.vertex(s[0] + rTop * x[i],   -h/2, rTop * z[i],   wTex/2 * (1 + z[i]),   hTex/2 * (1 + x[i]));
    geom.vertex(s[0] + rTop * x[i-1], -h/2, rTop * z[i-1], wTex/2 * (1 + z[i-1]), hTex/2 * (1 + x[i-1]));
    geom.vertex(s[0] + 0, -h/2, 0, wTex/2, hTex/2);
    geom.vertex(s[0] + 0, -h/2, 0, wTex/2, hTex/2);
  }
  for (int i = 1; i != x.length; ++i) { // bottom
    geom.vertex(rBase * x[i-1], h/2, rBase* z[i-1], wTex/2 * (1 + z[i-1]), hTex/2 * (1 + x[i-1]));
    geom.vertex(rBase * x[i],   h/2, rBase * z[i],  wTex/2 * (1 + z[i]),   hTex/2 * (1 + x[i]));
    geom.vertex(0, h/2, 0, wTex/2, hTex/2);
    geom.vertex(0, h/2, 0, wTex/2, hTex/2);
  }
  return geom.getShape();
}


PShape makeGear(float radius, float inner, float thickness, int nTeeth, float toothHeight, float pressure, float bevel, PImage tex, boolean shadow) {
  assert inner < radius;
  assert nTeeth > 0 : nTeeth;
  assert bevel < thickness;
  assert pressure >= 0 && pressure <= PI/4 : pressure;
  final boolean isBevel = bevel != 0;
  final float a = TWO_PI / nTeeth;
  final float b = a * pressure / PI;
  if (bevel == 0) bevel = (thickness * cos(b))/4;
  final float toothWidth = PI * radius / nTeeth;
  if (toothHeight <= 0) toothHeight = (int)toothWidth; 
  final float rt = radius + toothHeight;
  float wTex = 0, hTex = 0;  // texture width / height
  Geometry geom = new Geometry(shadow);
  if (tex != null) {
    wTex = tex.width;
    hTex = tex.height;
    geom.texture(tex);
  }
  // tooth vertices
  PVector[] v = { 
    new PVector(), new PVector(), new PVector(), new PVector(), new PVector()
  };
  // precompute some cosines and sines
  float[] c = new float[2 * nTeeth + 2];
  float[] s = new float[2 * nTeeth + 2];
  for (int i = 0; i != c.length; ++i) {
      c[i] = COS(a/2 * i);
      s[i] = SIN(a/2 * i);
  }
  for (int i = 0; i < nTeeth; ++i) {
    final float angle = a * i;
    v[0].x = radius * c[2*i];
    v[0].y = radius * s[2*i];
    v[0].z = thickness/2;
    v[1].x = rt * COS(angle + b);
    v[1].y = rt * SIN(angle + b);
    v[1].z = thickness/2 - bevel;
    v[2].x = rt * COS(angle + a/2 - b);
    v[2].y = rt * SIN(angle + a/2 - b);
    v[2].z = thickness/2 - bevel;
    v[3].x = radius * c[2 * i + 1];
    v[3].y = radius * s[2 * i + 1];
    v[3].z = thickness/2;
    v[4].x = radius * c[2 * i + 2];
    v[4].y = radius * s[2 * i + 2];
    v[4].z = thickness/2;

    for (int side = 1; side >=0; --side, geom.invertWinding = true) {
      for (int j = 0; j < 4; ++j) {
        float xTex = wTex/2 + wTex/(2*rt) * v[j].x;
        float yTex = hTex/2 + hTex/(2*rt) * v[j].y;
        float z = isBevel ? (side == 1 ? -v[j].z : thickness / 2) : (1 - 2 * side) * v[j].z;
        geom.vertex(v[j].x, v[j].y, z, xTex, yTex);
      }
    }
    geom.invertWinding = false;
    // teeth sides
    float wToothTile = wTex;
    float hToothTile = hTex/4;
    for (int k = 0; k < 4; ++k) {
      int n = i * 4 + k;
      float z0 = v[k].z, z1 = v[k+1].z;
      if (isBevel) z0 = z1 = thickness/2;
      float u0 = (-z0 + thickness/2) * wToothTile / thickness;
      float u1 = (-z1 + thickness/2) * wToothTile / thickness;
      float u2 = (v[k+1].z + thickness/2) * wToothTile / thickness;
      float u3 = (v[k].z + thickness/2) * wToothTile / thickness;
      geom.vertex(v[k].x,   v[k].y,    z0,       u0, 0);
      geom.vertex(v[k+1].x, v[k+1].y,  z1,       u1, hToothTile);
      geom.vertex(v[k+1].x, v[k+1].y, -v[k+1].z, u2, hToothTile);
      geom.vertex(v[k].x,   v[k].y,   -v[k].z,   u3, 0);
    }

    // gear face
    for (int k = 0; k != 2; ++k) {
      v[0].x = inner * c[2*i + k];
      v[0].y = inner * s[2*i + k];
      v[1].x = radius * c[2*i + k];
      v[1].y = radius * s[2*i + k];
      v[2].x = radius * c[2*i + k + 1];
      v[2].y = radius * s[2*i + k + 1];
      v[3].x = inner * c[2*i + k + 1];
      v[3].y = inner * s[2*i + k + 1];
      for (int side = 1; side >= 0; --side, geom.invertWinding = true) {
        float z = (1 - 2 * side) * thickness/2;        
        for (int j = 0; j < 4; ++j) {
          float xTex = wTex/2 + v[j].x * wTex / (2 * radius);
          float yTex = hTex/2 + v[j].y * hTex / (2 * radius);
          geom.vertex(v[j].x, v[j].y, z, xTex, yTex);
        }
      }
      if (inner > 0) {
        wToothTile = wTex * thickness / (2 * radius);
        hToothTile = hTex / (2 * nTeeth);
        int n = i * 2 + k;
        float hTexTile = hTex / nTeeth;
        geom.vertex(v[0].x, v[0].y, -thickness/2,  0,          hToothTile * n);
        geom.vertex(v[0].x, v[0].y,  thickness/2,  wToothTile, hToothTile * n);
        geom.vertex(v[3].x, v[3].y,  thickness/2,  wToothTile, hToothTile * (n + 1));
        geom.vertex(v[3].x, v[3].y, -thickness/2,  0,          hToothTile * (n + 1));
      }
      geom.invertWinding = false;
    }
  }
  return geom.getShape();
}


PShape makeOvoid(float r1 /* xz */, float r2 /* xy */, PImage tex, int nSides, boolean half, boolean shadow) {
  final int n = nSides + 1;
  float c[] = new float[n];
  float s[] = new float[n];
  float sr[] = new float[n];
  float cr[] = new float[n];
  for (int i = 0; i != nSides; ++i) {
    float a = TWO_PI/nSides * i;
    c[i] = COS(a);
    s[i] = SIN(a);
    a = PI/nSides * i;
    sr[i] = SIN(a);
    cr[i] = COS(a);
  }
  c[nSides] = 1.0;
  cr[nSides] = -1.0;

  Geometry geom = new Geometry(shadow);
  float tw = 0, th = 0;
  if (tex != null) {
    geom.texture(tex);
    tw = tex.width / nSides;
    th = tex.height / nSides;
  }

  final int begin = 0, end = nSides/2;
  for (int i0 = begin; i0 != end; ++i0) {
    final int i1 = i0 + 1;
    final float y0 = r1 * cr[ i0 ];
    final float y1 = r1 * cr[ i1 ];

    for (int j0 = 0; j0 != nSides; ++j0) {
      final int j1 = (j0 + 1) % nSides;
      float u = tw * j0;
      geom.invertWinding = false;
      geom.vertex(r2 * sr[ i0 ] * c[ j0 ], y0, r2 * sr[ i0 ] * s[ j0 ], u, th * i0);
      geom.vertex(r2 * sr[ i1 ] * c[ j0 ], y1, r2 * sr[ i1 ] * s[ j0 ], u, th * i1);
      geom.vertex(r2 * sr[ i1 ] * c[ j1 ], y1, r2 * sr[ i1 ] * s[ j1 ], u + tw, th * i1);
      geom.vertex(r2 * sr[ i0 ] * c[ j1 ], y0, r2 * sr[ i0 ] * s[ j1 ], u + tw, th * i0);
      if (half) continue;
      geom.invertWinding = true;
      geom.vertex(r2 * sr[ i0 ] * c[ j0 ], -y0, r2 * sr[ i0 ] * s[ j0 ], u, th * (nSides - i0));
      geom.vertex(r2 * sr[ i1 ] * c[ j0 ], -y1, r2 * sr[ i1 ] * s[ j0 ], u, th * (nSides - i1));
      geom.vertex(r2 * sr[ i1 ] * c[ j1 ], -y1, r2 * sr[ i1 ] * s[ j1 ], u + tw, th * (nSides - i1));
      geom.vertex(r2 * sr[ i0 ] * c[ j1 ], -y0, r2 * sr[ i0 ] * s[ j1 ], u + tw, th * (nSides - i0));
    }
  }
  geom.getShape().rotateX(PI); // oops
  return geom.getShape();
}


PShape makeTube(float radius, float inner, float h, PImage tex, int nSides, boolean shadow) {
  if (inner >= radius) inner = radius/2;
  float c[] = new float[nSides + 1];
  float s[] = new float[nSides + 1]; 
  for (int i = 0; i < c.length; ++i) {
    final float angle = TWO_PI / nSides * i;
    s[i] = SIN(angle);
    c[i] = COS(angle);
  }
  final int nSections = round(h / (TWO_PI * radius) + 0.5); 
  final float hSection = h / nSections;
  final float[] r = { radius, inner };
  Geometry geom = new Geometry(shadow);
  float tw = 0, th = 0, wTex = 0, hTex = 0;
  if (tex != null) {
    geom.texture(tex);
    wTex = tex.width;
    hTex = tex.height;
    tw = wTex / nSides;
    th = hTex / nSections;
  }
  for (int n = 0; n != nSections; ++n) {
   float y = n * hSection - h/2;
    for (int i = 1; i != c.length; ++i) {
      for (int j = 0; j != r.length; ++j) {
        geom.invertWinding = j == 1;
        geom.vertex(r[j] * c[i-1], y + hSection, r[j] * s[i-1], (i-1) * tw, th * (n + 1));
        geom.vertex(r[j] * c[i-1], y,            r[j] * s[i-1], (i-1) * tw, th * n);
        geom.vertex(r[j] * c[i],   y,            r[j] * s[i],   i * tw,     th * n);
        geom.vertex(r[j] * c[i],   y + hSection, r[j] * s[i],   i * tw,     th * (n + 1));
      }
    }
  }
  final float f = r[1]/r[0]; // inner/outer factor
  for (int i = 1; i != c.length; ++i) {
    for (int j = 0; j != 2; ++j) {
      geom.invertWinding = j == 1;      
      geom.vertex(r[0] * c[i],   -h/2 + h * j, r[0] * s[i],   wTex/2 * (1 + s[i]),   hTex/2 * (1 + c[i]));
      geom.vertex(r[0] * c[i-1], -h/2 + h * j, r[0] * s[i-1], wTex/2 * (1 + s[i-1]), hTex/2 * (1 + c[i-1]));
      geom.vertex(r[1] * c[i-1], -h/2 + h * j, r[1] * s[i-1], wTex/2 * (1 + f * s[i-1]), hTex/2 * (1 + f * c[i-1]));
      geom.vertex(r[1] * c[i],   -h/2 + h * j, r[1] * s[i],   wTex/2 * (1 + f * s[i]),   hTex/2 * (1 + f * c[i]));
    }
  }
  return geom.getShape();
}
