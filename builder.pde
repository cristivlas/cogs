import java.util.Stack;
//
// Utility classes that wrap geometry construction
//
class Params {
  <T> T get(String name, T defaultVal, Params other) {
    Object obj = param.get(name);
    if (obj != null) {
      T result = (T)obj;
      if (obj instanceof String && !(defaultVal instanceof String)) {
        return get((String)obj, defaultVal, other);
      }
      // allow converting integer to float
      if (defaultVal instanceof Float && obj instanceof Integer) {
        int i = (Integer)result;
        Float f = (float)i;
        return (T)f;
      }
      return result;
    }
    if (other != null) return other.get(name, defaultVal, null);
    return defaultVal;
  }
  Params set(String name, Object value) {
    param.put(name, value);
    return this;
  }
  private HashMap<String, Object> param = new HashMap();
}


class ShapeBuilder extends Params {
  static final int BOX = 1;
  static final int CONE = 2;
  static final int CYLINDER = 3;
  static final int GEAR = 4;
  static final int SPHERE = 5;
  static final int TUBE = 6;
  PShape pushGroup() {
    PShape group = createShape(GROUP);
    // parent it to the group on the top of the stack
    if (!stack.isEmpty()) stack.peek().addChild(group);
    stack.push(group);
    return group;
  }
  PShape popGroup() {
    return stack.pop();
  }
  State box() {
    return new State(BOX);
  }
  State cone() {
    return new State(CONE);
  }
  State cylinder() {
    return new State(CYLINDER);
  }
  State gear() {
    return new State(GEAR);
  }
  State sphere() {
    return new State(SPHERE);
  }
  State tube() {
    return new State(TUBE);
  }

  class State extends Params {    
    State(int kind) {
      this.kind = kind;
    }
    State set(String name, Object value) {
      super.set(name, value);
      return this;
    }
    // number of sides for cylinders, cones, spheres
    int detail() { 
      return get("detail", 32, ShapeBuilder.this);
    }
    float width() {
      return get("width", 200.0, ShapeBuilder.this);
    }
    float height() {
      return get("height", 200.0, ShapeBuilder.this);
    }
    float depth() {
      return get("depth", 200.0, ShapeBuilder.this);
    }
    float radius() {
      return get("radius", 100.0, ShapeBuilder.this);
    }
    float innerRadius() {
      return get("inner", 0.0, ShapeBuilder.this);
    }
    float topRadius() {
      return get("radiusTop", 0.0, ShapeBuilder.this);
    }
    float slope() {
      return get("slope", 0.0, ShapeBuilder.this);
    }
    boolean shadow() {
      return get("shadow", true, ShapeBuilder.this);
    }
    PImage texture() {
      return get("texture", null, ShapeBuilder.this);
    }
    int numTeeth() {
      return get("teeth", 16, ShapeBuilder.this);
    }
    float toothHeight() {
      return get("height", 0.0, ShapeBuilder.this);
    }
    float bevel() {
      return get("bevel", 0.0, ShapeBuilder.this);
    }
    float pressure() {
      return get("pressure", 0.0, ShapeBuilder.this);
    }
    State rotateX(float angle) {
      matrix.rotateX(angle);
      return this;
    }
    State rotateY(float angle) {
      matrix.rotateY(angle);
      return this;
    }
    State rotateZ(float angle) {
      matrix.rotateZ(angle);
      return this;
    }
    State translate(float x, float y, float z) {
      matrix.translate(x, y, z);
      return this;
    }
    PShape end() {
      PShape shape = null;
      switch (kind) {
      case BOX: 
        shape = makeBox(width(), height(), depth(), texture(), shadow()); 
        break;
      case CONE: 
        shape = makeCone(radius(), topRadius(), height(), texture(), detail(), slope(), shadow()); 
        break;
      case CYLINDER: 
        shape = makeCone(radius(), radius(), height(), texture(), detail(), 0, shadow()); 
        break;
      case GEAR: 
        shape = makeGear(radius(), innerRadius(), depth(), numTeeth(), toothHeight(), pressure(), bevel(), texture(), shadow()); 
        break;
      case SPHERE: 
        shape = makeOvoid(radius(), radius(), texture(), detail(), false, shadow()); 
        break;
      case TUBE:
        shape = makeTube(radius(), innerRadius(), height(), texture(), detail(), shadow());
        break;
      default: 
        assert false : "unexpected kind: " + kind; 
        break;
      }
      if (shape != null) {
        shape.applyMatrix(matrix);
      }
      if (!stack.isEmpty()) stack.peek().addChild(shape); // parent it to the current group
      return shape;
    }
    final int kind;
    PMatrix matrix = new PMatrix3D();
  }
  Stack<PShape> stack = new Stack(); // for groups
}
