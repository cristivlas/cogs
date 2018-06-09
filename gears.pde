import java.lang.ref.*;

//static int gcd(int a, int b) {
//  if (b == 0) return a;
//  return gcd(b, a % b);
//}

// Utility class for checking spatial collisions
class BoundingBox {
  BoundingBox(float width, float height, float depth) {
    for (int i = 0; i != v.length; ++i) v[i] = new PVector();
    w = width;
    h = height;
    d = depth;
  }  
  void draw() {
    if (shape == null) makeShape();
    shape.draw(g);
  }
  void applyMatrix(PMatrix3D matrix) {
    shape = null; // invalidate the shape
    v[0].set(-w/2, -h/2, -d/2);
    v[1].set( w/2, -h/2, -d/2);
    v[2].set(-w/2, -h/2, d/2);
    v[3].set( w/2, -h/2, d/2);
    v[4].set(-w/2, h/2, d/2);
    v[5].set( w/2, h/2, d/2);
    v[6].set(-w/2, h/2, -d/2);
    v[7].set( w/2, h/2, -d/2);
    for (int i = 0; i != v.length; ++i) {
      matrix.mult(v[i], v[i]);
      x[i] = v[i].x;
      y[i] = v[i].y;
      z[i] = v[i].z;
    }
  }
  void makeShape() {
    shape = createShape();
    shape.beginShape(QUAD_STRIP);
    shape.strokeWeight(1);
    shape.stroke(0, 200, 150);
    shape.noFill();
    for (int i = 0; i <= v.length+1; ++i) {
      int j = i % v.length;
      shape.vertex(v[j].x, v[j].y, v[j].z);
    }
    shape.endShape();
  }
  boolean intersects(BoundingBox other) {
    return intersects(other, 0);
  }
  boolean intersects(BoundingBox other, float margin) {
    if (max(x) + margin < min(other.x)) return false;
    if (min(x) - margin > max(other.x)) return false;     
    if (max(y) + margin < min(other.y)) return false;
    if (min(y) - margin > max(other.y)) return false;
    if (max(z) + margin < min(other.z)) return false;
    if (min(z) - margin > max(other.z)) return false;
    return true;
  }
  final float w, h, d;
  PVector v[] = new PVector[8]; // vertices for the eight corners
  float x[] = new float[8], y[] = new float[8], z[] = new float[8];
  PShape shape;
}


// Error codes
static final int ALREADY_CONNECTED = -1;
static final int NOT_ENOUGH_ROOM = 1;
static final int TOOTH_WIDTH_MISMATCH = 2;
static final int TOOTH_HEIGHT_MISMATCH = 3;
static final int PRESSURE_ANGLE_MISMATCH = 4;
static final int ROOT_RADIUS_MISMATCH = 5;
static final int INNER_RADIUS_MISMATCH = 6;
static final int TOOTH_NUMBER_MISMATCH = 7;


class ConnectException extends Exception {
  ConnectException(int errorCode, String message) {
    super(message);
    this.errorCode = errorCode;
  }
  final int errorCode;
}

/*-------------------------------------------------------------------------------------------
 *
 * Gears and related (Axle, Mechanism)
 *
 *-------------------------------------------------------------------------------------------*/
abstract class Gear {
  static final int KIND_SPUR  = 0;
  static final int KIND_BEVEL = 1;

  Gear(GearShapeBuilder builder, float rootRadius, float innerRadius, int numTeeth, float toothHeight, float pressureAngle) {
    assert this.kind() == builder.kind();
    if (rootRadius <= innerRadius) {
      PGraphics.showWarning("rootRadius must be greater than innerRadius");
      rootRadius = 1.5 * innerRadius;
    }
    this.rootRadius = rootRadius;
    this.innerRadius = innerRadius;
    this.numTeeth = numTeeth;
    this.toothHeight = toothHeight;
    this.pressureAngle = pressureAngle;
    this.shape = builder.build(this);
    assert thickness > 0; // expect the builder to set it
    box = new BoundingBox(2*radius(), 2*radius(), thickness);
  }

  WeakReference<Gear> getWeakRef() {
    if (self == null) self = new WeakReference(this);
    return self;
  }

  abstract int kind();

  void preDraw(int mode) {
    pushMatrix();
    applyMatrix(matrix);
  }

  void postDraw(int mode) {
    popMatrix();
    if (mode == Model.WIREFRAME) box.draw();
  }

  float radius() {
    return rootRadius + toothHeight;
  }
  
  float toothWidth() {
    return (PI * rootRadius) / numTeeth;
  }
  
  Gear connectSameAxle(Gear other, Mechanism mechanism) throws ConnectException {
    assert other.innerRadius > 0;
    if (driver != null) throw new ConnectException(ALREADY_CONNECTED, this + "already connected");
    if (!EQUAL(innerRadius, other.innerRadius)) {
      throw new ConnectException(INNER_RADIUS_MISMATCH, "Inner radius " + innerRadius + " does not match " + other.innerRadius);
    }
    final float spacing = random(20, 3 * (thickness + other.thickness) / 2.0);
    PMatrix3D temp = matrix.get();
    for (int i = 0; i != 2; ++i) { // try front and back
      setMatrix(other);
      translate(0, 0, (1 - 2 * i) * ((thickness + other.thickness) / 2 + spacing));
      if (mechanism.collides(this, other)) continue;
      if (!mechanism.addAxle(this, other)) continue;
      if (i == 0) {
        rotateY(PI);
        updateBoundingBox();
        flip = true;
      }
      driver = other.getWeakRef();
      return mechanism.add(this);
    }
    matrix = temp;
    throw new ConnectException(NOT_ENOUGH_ROOM, "Not enough room");
  }

  abstract Gear connectSameKind(Gear other, Mechanism mechanism) throws ConnectException;

  void setMatrix(Gear other) {
    matrix.set(other.matrix);
  }
  
  void translate(float x, float y, float z) {
    matrix.translate(x, y, z);
  }
  
  void rotateX(float a) {
    matrix.rotateX(a);   
  }
  
  void rotateY(float a) {
    matrix.rotateY(a);
  }
  
  void rotateZ(float a) {
    matrix.rotateZ(a);
  }
  
    
  void updateBoundingBox() {
    box.applyMatrix(matrix);
  }

  void updateMotion() {
    matrix.rotateZ(speed);
  }

  void updateSpeed() {
    if (driver == null) return;
    Gear other = driver.get();
    if (axle != null && axle == other.axle) {
      speed = flip ? -other.speed : other.speed;
    } else {
      speed = -other.speed * (float)other.numTeeth / numTeeth;
    }
  }

  float thickness = 0;      // set by the builder
  final float rootRadius;   // radius not including tooth height
  final float innerRadius;  // inner (axle hole) radius
  final int numTeeth;
  final float toothHeight;
  final float pressureAngle;
  final PShape shape; 
  PMatrix3D matrix = new PMatrix3D();
  float speed = 0;
  boolean flip = false;
  WeakReference<Axle> axle;
  WeakReference<Gear> driver;
  WeakReference<Gear> self;
  BoundingBox box;
}


class Axle {
  Axle() {
  }

  Axle(Axle other) {
    gears = (ArrayList)other.gears.clone();
  }

  WeakReference getWeakRef() {
    if (self == null) self = new WeakReference(this);
    return self;
  }

  void set(Axle other) {
    if (this != other) {
      gears = other.gears;
      matrix = other.matrix;
      shape = other.shape;
      box = other.box;
    }
    for (WeakReference<Gear> g : gears) g.get().axle = getWeakRef();
  }

  void preDraw(int mode) {
    pushMatrix();
    applyMatrix(matrix);
  }

  void postDraw(int mode) {
    popMatrix();
    if (mode == Model.WIREFRAME) box.draw();
  }

  void makeShape(ShapeBuilder shapeBuilder) {
    assert matrix == null;
    assert shape == null;
    PVector vmin = null, vmax = null;
    float maxThickness = 0, radius = 0;
    for (WeakReference<Gear> g : gears) {
      Gear gear = g.get();
      if (gear.thickness > maxThickness) maxThickness = gear.thickness;
      PMatrix3D m = gear.matrix;
      PVector pos = new PVector(m.m03, m.m13, m.m23);
      if (matrix != null) {
        assert radius > 0;
        assert EQUAL(radius, gear.innerRadius);
      } else {
        matrix = m.get();
        vmin = pos.get();
        vmax = pos.get();
        radius = gear.innerRadius;
      }
      if (vmin != null && vmax !=null) {
        if (pos.x < vmin.x) vmin.x = pos.x;
        if (pos.x > vmax.x) vmax.x = pos.x;
        if (pos.y < vmin.y) vmin.y = pos.y;
        if (pos.y > vmax.y) vmax.y = pos.y;
        if (pos.z < vmin.z) vmin.z = pos.z;
        if (pos.z > vmax.z) vmax.z = pos.z;
      }
    }
    final PVector vmid = new PVector((vmin.x + vmax.x)/2, (vmin.y + vmax.y)/2, (vmin.z + vmax.z)/2);
    final float h = vmin.dist(vmax) + 1.5 * maxThickness;
    final float r = 0.9 * radius;
    if (r < 20 || random(1) < 0.5) {
      shape = shapeBuilder.tube().set("height", h).set("radius", r).set("inner", r/2).set("texture", "texture-3").end();      
    }
    else {
      shape = shapeBuilder.cylinder().set("height", h).set("radius", r).set("texture", "texture-3").end();      
    }
    shape.rotateX(HALF_PI);
    matrix.m03 = vmid.x;
    matrix.m13 = vmid.y;
    matrix.m23 = vmid.z;
    box = new BoundingBox(2 * r, 2 * r, h);
    box.applyMatrix(matrix);
  }

  ArrayList<WeakReference<Gear>> gears = new ArrayList();
  PMatrix3D matrix;
  PShape shape;
  BoundingBox box;
  WeakReference<Axle> self;
}


class Spur extends Gear {
  Spur(GearShapeBuilder builder, float rootRadius, float innerRadius, int numTeeth, float toothHeight, float pressureAngle) {
    super(builder, rootRadius, innerRadius, numTeeth, toothHeight, pressureAngle);
  }

  int kind() {
    return Gear.KIND_SPUR;
  }

  Gear connectSameKind(Gear other, Mechanism mechanism) throws ConnectException {
    if (driver != null) throw new ConnectException(ALREADY_CONNECTED, this + "already connected");
    if (!EQUAL(toothWidth(), other.toothWidth())) {
      throw new ConnectException(TOOTH_WIDTH_MISMATCH, "Tooth width " + toothWidth() + " does not match " + other.toothWidth());
    }
    if (!EQUAL(pressureAngle, other.pressureAngle)) {
      throw new ConnectException(PRESSURE_ANGLE_MISMATCH, "Pressure angle " + pressureAngle + " does not match " + other.pressureAngle);
    }
    final PMatrix3D temp = matrix.get();
    final float r = rootRadius + other.rootRadius + 1.5 * max(toothHeight, other.toothHeight);
    for (float a = 0; a < TWO_PI; a += HALF_PI) {
      setMatrix(other);
      rotateZ(a);
      translate(r, 0, 0);
      if (!mechanism.collides(this, other)) {
        driver = other.getWeakRef();
        return mechanism.add(this);
      }
    }
    matrix = temp;
    throw new ConnectException(NOT_ENOUGH_ROOM, "Not enough room");
  }
}


class Bevel extends Gear {
  Bevel(GearShapeBuilder builder, float rootRadius, float innerRadius, int numTeeth, float toothHeight, float pressureAngle) {
    super(builder, rootRadius, innerRadius, numTeeth, toothHeight, pressureAngle);
  }

  int kind() {
    return Gear.KIND_BEVEL;
  }

  Gear connectSameKind(Gear other, Mechanism mechanism) throws ConnectException {
    if (driver != null) throw new ConnectException(ALREADY_CONNECTED, this + "already connected");
    if (!EQUAL(rootRadius, other.rootRadius)) {
      throw new ConnectException(ROOT_RADIUS_MISMATCH, "Root radius " + rootRadius + " does not match " + other.rootRadius);
    }
    if (!EQUAL(toothHeight, other.toothHeight)) {
      throw new ConnectException(TOOTH_HEIGHT_MISMATCH, "Tooth height " + toothHeight + " does not match " + other.toothHeight);
    }
    if (numTeeth != other.numTeeth) {
      throw new ConnectException(TOOTH_NUMBER_MISMATCH, "Number of teeth  " + numTeeth + " does not match " + other.numTeeth);
    }
    PMatrix3D temp = matrix.get();
    final float r = other.rootRadius + other.thickness / 2;
    for (float a = 0; a < TWO_PI; a += HALF_PI) {
      setMatrix(other);
      rotateZ(a);
      translate(r, 0, -r);
      rotateY(HALF_PI);
      if (mechanism.collides(this, other)) continue;
      driver = other.getWeakRef();
      return mechanism.add(this);
    }
    matrix = temp;
    throw new ConnectException(NOT_ENOUGH_ROOM, "Not enough room");
  }
}

//
// Gear shape builders
//
abstract class GearShapeBuilder {  
  GearShapeBuilder(ShapeBuilder shapeBuilder) {
    this.shapeBuilder = shapeBuilder;
  }
  final PShape build(Gear gear) {
    shapeBuilder.pushGroup();
    shapeBuilder.set("radius", gear.rootRadius);
    shapeBuilder.set("inner", gear.innerRadius);
    shapeBuilder.set("teeth", gear.numTeeth);
    shapeBuilder.set("pressure", gear.pressureAngle);
    shapeBuilder.set("height", gear.toothHeight);
    buildImpl(gear);
    return shapeBuilder.popGroup();
  }
  abstract void buildImpl(Gear gear);
  abstract int kind();
  final ShapeBuilder shapeBuilder;
}


class SpurBuilder extends GearShapeBuilder {
  SpurBuilder(ShapeBuilder shapeBuilder) {
    super(shapeBuilder);
  }
  final int kind() {
    return Gear.KIND_SPUR;
  }
  void buildImpl(Gear gear) {
    shapeBuilder.set("depth", gear.thickness = max(16, gear.rootRadius/4));
    if (gear.rootRadius <= gear.innerRadius + 20) {
      shapeBuilder.gear().end();
    } else {
      shapeBuilder.gear().set("inner", gear.rootRadius - 15).end();
      shapeBuilder.tube().set("radius", gear.rootRadius - 15).set("inner", gear.innerRadius + 5).rotateX(HALF_PI).end();
      shapeBuilder.tube().set("radius", gear.innerRadius + 5).set("inner", gear.innerRadius).rotateX(HALF_PI).set("height", 40).end();
    }
  }
}


class SpokedSpurBuilder extends GearShapeBuilder {
  static final int NUM_SPOKES = 7;

  SpokedSpurBuilder(ShapeBuilder shapeBuilder) {
    super(shapeBuilder);
  }
  
  final int kind() {
    return Gear.KIND_SPUR;
  }
  
  void buildImpl(Gear gear) {
    shapeBuilder.set("depth", gear.thickness = max(10, gear.rootRadius/5));
    if (gear.rootRadius <= gear.innerRadius + 20) {
      shapeBuilder.gear().end();
    } else {
      float off = gear.rootRadius / 8;
      if (off < 5) off = 5;
      float spokeSize = gear.rootRadius - gear.innerRadius - 2 * off;
      String texture = "texture-" + (int)random(1, 6);
      shapeBuilder.gear().set("texture", texture).set("radius", gear.innerRadius + off).set("pressure", PI/6).set("teeth", NUM_SPOKES).set("height", spokeSize).end();
      shapeBuilder.gear().set("texture", texture).set("inner", gear.rootRadius - off).end();
    }
  }
}


class BevelBuilder extends GearShapeBuilder {
  BevelBuilder(ShapeBuilder shapeBuilder) {
    super(shapeBuilder);
  }
  final int kind() {
    return Gear.KIND_BEVEL;
  } 
  void buildImpl(Gear gear) {
    shapeBuilder.set("depth", gear.thickness = gear.toothHeight + 5);
    shapeBuilder.gear().set("bevel", gear.toothHeight).end();
  }
}

//
// Collection of gears and axles;
// spatial bounds and collision checker;
// factory
//
abstract class Mechanism extends Model {
  Mechanism() {
    this(800, 600, 600);
  }

  Mechanism(int width, int height, int depth) {
    setBounds(width, height, depth);
    // textures from http://www.mb3d.co.uk/mb3d/Metal_Rusty_and_Patterned_Seamless_and_Tileable_High_Res_Textures_files/
    shapeBuilder.set("texture-1", loadImage("Steel_02_UV_H_CM_1.jpg"));
    shapeBuilder.set("texture-2", loadImage("Metal_Worn_Painted_Panel_Black_Red_Rusty_UV_CM_1.jpg"));
    shapeBuilder.set("texture-3", loadImage("Lead_03_UV_H_CM_1.jpg"));
    shapeBuilder.set("texture-4", loadImage("Dirty_Steel_01_UV_H_CM_1.jpg"));
    shapeBuilder.set("texture-5", loadImage("Rust_02_UV_H_CM_1.jpg"));
//    shapeBuilder.set("texture-5", loadImage("Dirty_Steel_02_UV_H_CM_1.jpg"));
    shapeBuilder.set("texture", "texture-1"); // set default texture
    // populate gear shape builders
    for (int i = 0; i != builders.length; ++i) builders[i] = new ArrayList();
    builders[Gear.KIND_SPUR].add(new SpurBuilder(shapeBuilder));
    builders[Gear.KIND_SPUR].add(new SpokedSpurBuilder(shapeBuilder));
    builders[Gear.KIND_BEVEL].add(new BevelBuilder(shapeBuilder));
  }

  void setBounds(int width, int height, int depth) {
    final int wallThickness = max(width, height, depth);
    PMatrix3D matrix = new PMatrix3D();
    // left
    matrix.reset();
    matrix.translate(-width/2 - wallThickness/2, 0, 0);
    matrix.rotateY(HALF_PI);
    bounds[0] = new BoundingBox(depth, height, wallThickness);
    bounds[0].applyMatrix(matrix);
    // right
    matrix.reset();
    matrix.translate(width/2 + wallThickness/2, 0, 0);
    matrix.rotateY(-HALF_PI);
    bounds[1] = new BoundingBox(depth, height, wallThickness);
    bounds[1].applyMatrix(matrix);
    // top
    matrix.reset();
    matrix.translate(0, -height/2 - wallThickness/2, 0);
    matrix.rotateX(HALF_PI);
    bounds[2] = new BoundingBox(width, depth, wallThickness);
    bounds[2].applyMatrix(matrix);
    // bottom
    matrix.reset();
    matrix.translate(0, height/2 + wallThickness/2, 0);
    matrix.rotateX(-HALF_PI);
    bounds[3] = new BoundingBox(width, depth, wallThickness);
    bounds[3].applyMatrix(matrix);
    // back
    matrix.reset();
    matrix.translate(0, 0, -depth/2 - wallThickness/2);
    bounds[4] = new BoundingBox(width, height, wallThickness);
    bounds[4].applyMatrix(matrix);
    // front
    matrix.reset();
    matrix.translate(0, 0, depth/2 + wallThickness/2);
    bounds[5] = new BoundingBox(width, height, wallThickness);
    bounds[5].applyMatrix(matrix);
  }

  boolean addAxle(Gear newGear, Gear oldGear) {
    assert newGear.axle == null;
    // make tentative axle
    Axle axle = null;
    if (oldGear.axle == null) {
      axle = new Axle();
      axle.gears.add(oldGear.getWeakRef());
    } else {
      axle = new Axle(oldGear.axle.get());
    }
    axle.gears.add(newGear.getWeakRef());
    axle.makeShape(shapeBuilder);
    if (collides(axle, oldGear.axle)) return false;
    // commit the axle
    if (oldGear.axle != null) {
      oldGear.axle.get().set(axle);
      axle = oldGear.axle.get();
    } else {
      axles.add(axle);
      axle.set(axle);
    }
    assert newGear.axle == oldGear.axle;
    assert axles.indexOf(oldGear.axle.get()) != -1;
    assert axles.indexOf(newGear.axle.get()) != -1;
    return true;
  }

  Gear add(Gear gear) {
    assert gears.indexOf(gear) == -1;
    gears.add(gear);
    shapes.add(gear.shape);
    return gear;
  }

  boolean collides(Axle axle, WeakReference<Axle> ignore) {
    for (Axle other : axles) {
      if (other.getWeakRef() == ignore) continue;
      if (axle.box.intersects(other.box)) return true;
    }
    for (Gear gear : gears) {
      if (axle.gears.indexOf(gear.getWeakRef()) >= 0) continue;
      if (axle.box.intersects(gear.box)) return true;
    }
    return false;
  }

  boolean collides(Gear gear, Gear ignore) {
    gear.updateBoundingBox();
    for (BoundingBox b : bounds) {
      if (gear.box.intersects(b)) return true;
    }
    for (Axle axle : axles) {
      assert axle.getWeakRef() != gear.axle;
      if (axle.getWeakRef() == ignore.axle) continue;
      if (gear.box.intersects(axle.box)) return true;
    }
    for (Gear other : gears) {
      if (other == gear || other == ignore) continue;
      if (gear.box.intersects(other.box, 5 /* margin */)) return true;
    }
    return false;
  }

  void drawBounds() {
    for (BoundingBox box : bounds) box.draw();
  }

  void preDraw(int i, int mode) {
    if (!haveAxleShapes) {
      for (Axle a : axles) shapes.add(a.shape);
      haveAxleShapes = true;
    }
    if (i == 0 && mode == Model.WIREFRAME) drawBounds();
    if (i < gears.size()) gears.get(i).preDraw(mode);
    else axles.get(i - gears.size()).preDraw(mode);
  }

  void postDraw(int i, int mode) {
    if (i < gears.size()) gears.get(i).postDraw(mode);
    else axles.get(i - gears.size()).postDraw(mode);
  }

  void reset() {
    pos.set(width/2, height/2, -width/8);
    rot.set(0, 0, 0);
  }

  void update() {
    for (Gear gear : gears) {
      gear.updateMotion();
      gear.updateSpeed();
    }
    for (Axle axle : axles) {
      assert !axle.gears.isEmpty();
      Gear first = axle.gears.get(0).get();
      axle.shape.rotateZ(first.speed);
    }
  }

  Gear makeGear(int kind, int style, float rootRadius, float innerRadius, int numTeeth, float toothHeight, float pressureAngle) {
    if (style < 0) style = (int)random(builders[kind].size());
    GearShapeBuilder builder = builders[kind].get(style);
    Gear gear = null;
    switch (kind) {
    case Gear.KIND_SPUR: 
      gear = new Spur(builder, rootRadius, innerRadius, numTeeth, toothHeight, pressureAngle); 
      break;
    case Gear.KIND_BEVEL: 
      gear = new Bevel(builder, rootRadius, innerRadius, numTeeth, toothHeight, pressureAngle); 
      break;
    }
    assert gear != null;
    return gear;
  }

  ShapeBuilder shapeBuilder = new ShapeBuilder();
  ArrayList<GearShapeBuilder> builders[] = new ArrayList[2];  
  ArrayList<Gear> gears = new ArrayList();
  ArrayList<Axle> axles = new ArrayList();
  BoundingBox bounds[] = new BoundingBox[6];
  boolean haveAxleShapes = false;
}


/*-------------------------------------------------------------------------------------------
 *
 * Concrete mechanisms
 *
 *-------------------------------------------------------------------------------------------*/
class GeneratedMechanism extends Mechanism {
  static final int SAME_AXLE_MIN_ROOT_RADIUS = 30;
  static final int SAME_AXLE_MAX_ROOT_RADIUS = 150;
  static final int SAME_AXLE_MAX_GEAR_COUNT = 5;
  
  Gear makeConnectedGear(Gear other, int kind, int numTeeth) throws ConnectException {
    return makeConnectedGear(other, kind, 0, numTeeth, false);
  }

  Gear makeConnectedGear(Gear other, int kind, int style, int numTeeth, boolean forceSameAxle) throws ConnectException {
    assert gears.indexOf(other) >= 0 : "Gear does not belong to this mechanism";
    if (numTeeth < 3) {
      throw new ConnectException(TOOTH_NUMBER_MISMATCH, "Mininum expected number of teeth not met, got:" + numTeeth);
    }
    float rootRadius = random(0.75 * other.rootRadius, 1.25 * other.rootRadius);
    float innerRadius = other.innerRadius;
    float toothHeight = other.toothHeight;

    // 1) try meshing gears
    if (!forceSameAxle && kind == other.kind()) {
      final int teeth = numTeeth;
      try {
        if (kind == Gear.KIND_BEVEL) {
          numTeeth = other.numTeeth;
          rootRadius = other.rootRadius;
          toothHeight = other.toothHeight;
        } else {
          rootRadius = other.toothWidth() * numTeeth / PI;
          if (toothHeight > rootRadius/4) toothHeight = rootRadius/4;
        }
        // randomize inner radius, to make it more interesting
        innerRadius = random(rootRadius/4, rootRadius/3);
        Gear gear = makeGear(kind, style, rootRadius, innerRadius, numTeeth, toothHeight, other.pressureAngle);
        return gear.connectSameKind(other, this);
      }
      catch (ConnectException e) {
      }
      numTeeth = teeth;
      innerRadius = other.innerRadius;
    }
    // 2) try mount on same axle
    if (other.axle != null && other.axle.get().gears.size() >= SAME_AXLE_MAX_GEAR_COUNT) {
      throw new ConnectException(NOT_ENOUGH_ROOM, "Per axle maximum gear count exceeded");
    }
    rootRadius = constrain(rootRadius, SAME_AXLE_MIN_ROOT_RADIUS, SAME_AXLE_MAX_ROOT_RADIUS);
    if (toothHeight > rootRadius/4) toothHeight = rootRadius/4;
    Gear gear = makeGear(kind, style, rootRadius, other.innerRadius, numTeeth, toothHeight, other.pressureAngle);
    return gear.connectSameAxle(other, this);
  }
}


class TestMechanism extends GeneratedMechanism {
  TestMechanism() {
//    Gear driver = makeGear(Gear.KIND_SPUR, 1 /* style */, 100 /* root */, 20, 16 /* teeth */, 20 /* height */, PI/6);
//    add(driver);
//    try {
//      for (int i = 0; i != 4; ++i) {
//        Gear gear = makeConnectedGear(driver, Gear.KIND_SPUR, 14);
//        if (i == 3) {
//          makeConnectedGear(gear, Gear.KIND_SPUR, 12);
//        }
//      }
//    }
//    catch (Exception e) {
//      println(e);
//    }
    Gear driver = makeGear(Gear.KIND_BEVEL, 0 /* style */, 40 /* root */, 30 /* inner */, 16 /* teeth */, 10 /* height */, PI/6);
    add(driver);
    driver.speed = 0.005;
    driver.rotateY(PI);
    driver.updateBoundingBox();
    try {         
      //Gear gear1 = makeConnectedGear(driver, Gear.KIND_BEVEL, 16);
      //Gear gear2 = makeConnectedGear(driver, Gear.KIND_BEVEL, 16);
      Gear gear3 = makeConnectedGear(driver, Gear.KIND_BEVEL, -1, 20, true);
      Gear gear4 = makeConnectedGear(gear3, Gear.KIND_BEVEL, 20);
      Gear gear5 = makeConnectedGear(gear4, Gear.KIND_BEVEL, 20);

      Gear gear = makeGear(Gear.KIND_SPUR, 0 /* style */, 100 /* root */, gear5.innerRadius, 16 /* teeth */, 20 /* height */, PI/6);
      gear.connectSameAxle(gear5, this);
      makePart2(gear);
      println("SUCCESS");
    }
    catch (ConnectException e) {
      println(e);
    }
  }

  void makePart2(Gear driver) throws ConnectException {
    Gear gear1 = makeConnectedGear(driver, Gear.KIND_SPUR, -1, 16, false);
    Gear gear2 = makeConnectedGear(gear1, Gear.KIND_SPUR, -1, 8, false);
    Gear gear3 = makeConnectedGear(gear1, Gear.KIND_SPUR, -1, 10, false);
    Gear gear4 = makeConnectedGear(gear1, Gear.KIND_SPUR, 1, 20, false);
    Gear gear5 = makeConnectedGear(driver, Gear.KIND_SPUR, -1, 16, false);  
    Gear gear6 = makeConnectedGear(gear5, Gear.KIND_BEVEL, 12);
    Gear gear7 = makeConnectedGear(gear6, Gear.KIND_BEVEL, 12);
    Gear gear8 = makeConnectedGear(gear1, Gear.KIND_BEVEL, 16);
  }
}


class RandomMechanism extends GeneratedMechanism {
  final float ratio[] = { 
    0.5, 1, 1.6, 2.0,
  };
  final static int MIN_TEETH = 8, MAX_TEETH = 96;

  RandomMechanism() {
    final int MAX_GEARS = 32;
    Stack<Gear> stack = new Stack(); // for backtracking
    Gear gear = makeGear(Gear.KIND_SPUR, 0 /* style */, 70 /* root */, 20 /* inner */, 16 /* teeth */, 20 /* height */, PI/8);
    gear.speed = 0.007;
    add(gear);
    gear.updateBoundingBox();

    while (gears.size () < MAX_GEARS) {
      int kind = (int)random(2);
      try {
        int numTeeth = int(ratio[(int)random(ratio.length)] * gear.numTeeth);
        if (numTeeth < (kind == Gear.KIND_BEVEL ? 16 : MIN_TEETH)) numTeeth *= 2;
        else while (numTeeth > MAX_TEETH) numTeeth /= 2;
        gear = makeConnectedGear(gear, kind, -1, numTeeth, false);
        stack.push(gear.driver.get());
        stack.push(stack.get(stack.size()/2));
      }
      catch (ConnectException e) {
        if (stack.isEmpty()) break;
        gear = stack.pop();
      }
    }
  }
}
