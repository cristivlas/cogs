abstract class Model {
  static final int NORMAL = 0;
  static final int WIREFRAME = 1;
  
  abstract void reset();
  abstract void update();
  void preDraw(int index, int mode) {
  }
  void postDraw(int index, int mode) {
  }

  final void draw(int mode) {
    pushMatrix();
    translate(pos.x, pos.y, pos.z);
    rotateX(rot.x);
    rotateY(rot.y);
    rotateZ(rot.z);
    for (int i = 0; i != shapes.size(); ++i) {
      PShape shape = shapes.get(i);
      if (mode == WIREFRAME) {
        PShape wire = wireframes.get(shape);
        if (wire == null) {
          //wire = copyWire(shape);
          //The above gets the vertices without the transformation matrix
          //applied to them, and the matrix is protected inside PShape; 
          //so I use the tessellated shape instead 
          wire = copyWire(shape.getTessellation());
          wireframes.put(shape, wire); 
        }
        shape = wire;
      }
      preDraw(i, mode);
      shape.draw(g);
      postDraw(i, mode);
    }
    popMatrix();
  }
 
  ArrayList<PShape> shapes = new ArrayList();
  HashMap<PShape, PShape> wireframes = new HashMap();
  PVector pos = new PVector();
  PVector rot = new PVector();
}

static void copyVertices(PShape src, PShape dest) {
  final int n = src.getVertexCount();
  for (int i = 0; i != n; ++i) {
    PVector v = src.getVertex(i);
    dest.vertex(v.x, v.y, v.z);
  }
}

PShape copyWire(PShape shape) {
  PShape wire = createShape();
  wire.beginShape(LINES);
  wire.noFill();
  wire.stroke(0, 100, 150);
  wire.strokeWeight(1);
  switch (shape.getKind()) {
    case PShape.GROUP:
      for (int i = 0; i != shape.getChildCount(); ++i) {
        copyVertices(shape.getChild(i), wire);
      }
      break;
    case PShape.TRIANGLES:
      copyVertices(shape, wire);
      break;
    default:
      assert false : "unsupported shape kind " + shape.getKind();
      break;
  }
  wire.endShape(CLOSE);
  return wire;
}


//
// A concrete model example.
//
class SpinnerModel extends Model {
  SpinnerModel() {
    ShapeBuilder builder = new ShapeBuilder();
    builder.set("texture", loadImage("Steel_02_UV_H_CM_1.jpg"));
    builder.pushGroup();
    builder.sphere().set("radius", 50).translate(0, 0, -200).end();
    builder.box().set("width", 60).set("height", 60).set("depth", 200).end();
    builder.cylinder().set("radius", 60).set("height", 150).rotateX(HALF_PI).end();
    builder.cone().set("radius", 30).set("height", 400).rotateX(HALF_PI).end();    
    shapes.add(builder.popGroup());
    builder.pushGroup();
    builder.gear().set("radius", 240).set("inner", 180).set("depth", 60).set("teeth", 25).set("pressure", PI/6).end();
    builder.tube().set("radius", 210).set("inner", 180).set("height", 15).rotateX(HALF_PI).translate(0, 35, 0).end();
    builder.gear().set("radius", 110).set("inner", 80).set("depth", 40).set("teeth", 5).set("pressure", PI/8).set("height", 80).end();
    shapes.add(builder.popGroup());
  }  
  void reset() {
     rot.set(PI/3, -PI/8, 0);
     pos.set(width/2, height/2, -height/4);
  }  
  void update() {
    if (keyPressed || mousePressed) return;
    rot.z += 0.003;
    PShape shape = shapes.get(1);
    shape.rotateZ(-0.005);
  }
}
