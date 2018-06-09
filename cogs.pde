import java.awt.Rectangle;


static ViewBox viewBox;
static boolean fullscreen = false, help = false;
static int modelType = 1;
static int helpWidth = 300;
static Rectangle bounds;


void setup() {
  size(1300, 700, P3D);
  surface.setResizable(true);
  if (frame.isUndecorated()) {
    surface.setSize(displayWidth, displayHeight);
  }
  else {
    surface.setSize(1300, 700);
  }
  viewBox = new ViewBox();
  toggleHelp();
}

void draw() {
  float fov = PI/3.0;
  float w = (viewBox.left + viewBox.right);
  float h = (viewBox.top + viewBox.bottom);
  camera(w/2, h/2, (h/2) / tan(fov/2), w/2, h/2, 0, 0, 1, 0);
  viewBox.update();
  viewBox.draw();
  camera();
  viewBox.drawHelp();
  viewBox.drawInfo();
}

void keyPressed() {
  switch(key) {
  case 'f': case 'F':
    toggleFullScreen();
    break;
  case 'h': case 'H':
    toggleHelp();
    break;
  case 'p': case 'P':
    takeSnapshot();
    break;
  }
}

void mouseMoved() {
  viewBox.mouseMoved();
}

void mouseWheel(MouseEvent e) {
  viewBox.mouseWheel(e);
}

void takeSnapshot() {
  String filename = millis() + ".jpg";
  saveFrame("snapshots/" + filename);
}

PImage tintAndFlipVertical(PImage img) {
  PGraphics flip = createGraphics(img.width, img.height, P3D);
  flip.beginDraw();
  flip.rotateY(PI);
  flip.tint(255, 255, 180, 250);
  flip.image(img, -img.width, 0);
  flip.endDraw();
  return flip.get();
}

void toggleFullScreen() {
  if (frame.isUndecorated()) return;
  fullscreen ^= true;
  if (fullscreen) {
    size(displayWidth, displayHeight, P3D);
    bounds = frame.getBounds();
    frame.setBounds(0, 0, width, height);
  }
  else {
    size(bounds.width, bounds.height, P3D);
    frame.setBounds(bounds.x, bounds.y, bounds.width, bounds.height);
  }
  viewBox = new ViewBox();
}

void toggleHelp() {
  help ^= true;
  viewBox.setBounds();
}


/*-------------------------------------------------------------------------------------------
 *
 * View and manipulate model. Singleton.
 *
 *-------------------------------------------------------------------------------------------*/
class ViewBox {
  final int KEY_MODEL = SHIFT;

  ViewBox() {
    setBounds();
    resetModel();
    resetLight();
    setShadowProjectionMatrix();
  }

  // For closing shadow volumes at infinity
  void setShadowProjectionMatrix() {
    final float fov = PI/3.0; 
    final float aspect = (float)width/height;
    float cameraZ = (height/2.0) / tan(fov/2);
    float near = cameraZ / 10.0;
    float top = near * tan(fov/2);
    float bottom = -top;
    float left = bottom * aspect;
    float right = top * aspect;
    PMatrix3D m = new PMatrix3D(
      2 * near/(right - left), 0, (right + left)/(right - left), 0, 
      0, -2 * near / (top - bottom), (top + bottom)/(top - bottom), 0, 
      0, 0, -1, -2 * near, 
      0, 0, -1, 0);
    m.transpose();
    volume.set("shadowProjection", m);
  }
  
  void setViewport(PGL pgl) {
    translate((right + left - width) / 2, (bottom + top - height) / 2, (back + front)/2);
    pgl.viewport((int)left, (int)(height - bottom), (int)(right - left), (int)(bottom - top));
  }
  
  void draw() {
    background(40);
    pushMatrix();
  
    PGL pgl = beginPGL();
    setViewport(pgl);
    
    pgl.frontFace(PGL.CCW);
    // base lights
    pointLight(100, 90, 90, lightPos.x, lightPos.y, lightPos.z);
    directionalLight(50, 50, 50, 0, -1, 0);

    if (shadowMode && !wireframeMode) {
      pgl.depthFunc(PGL.LEQUAL);
      drawBox();
      drawModel();
      // enable stencil buffer
      pgl.enable(PGL.STENCIL_TEST);    
      pgl.clear(PGL.STENCIL_BUFFER_BIT);
      pgl.stencilMask(0xff);
      pgl.stencilFunc(PGL.ALWAYS, 0, 0xff);
      // draw shadows to stencil buffer
      pgl.depthMask(false);
      pgl.colorMask(false, false, false, false);
      shader(volume);
//      pgl.stencilOpSeparate(PGL.FRONT, PGL.KEEP, PGL.KEEP, PGL.INCR_WRAP);
//      pgl.stencilOpSeparate(PGL.BACK, PGL.KEEP, PGL.KEEP, PGL.DECR_WRAP);
      pgl.stencilOpSeparate(PGL.FRONT, PGL.KEEP, PGL.INCR_WRAP, PGL.KEEP);
      pgl.stencilOpSeparate(PGL.BACK, PGL.KEEP, PGL.DECR_WRAP, PGL.KEEP);
      drawModel();
      resetShader();
      pgl.colorMask(true, true, true, true);
      pgl.depthMask(true);

      pgl.stencilFunc(PGL.EQUAL, 0, 0xff);
      pgl.stencilOp(PGL.KEEP, PGL.KEEP, PGL.KEEP);
      pgl.depthFunc(PGL.EQUAL);
    }
    // draw fully lit scene
    ambientLight(100, 100, 100);
    pointLight(155, 155, 155, lightPos.x, lightPos.y, lightPos.z);
    drawBox();
    drawModel();
    pgl.disable(PGL.STENCIL_TEST);
    endPGL();
    popMatrix();
  }

  void drawBox() {
    pushMatrix();
    translate(width/2, height/2, 0);
    if (wireframeMode) box.getTessellation().draw(g);
    else box.draw(g);
    popMatrix();
  }

  void drawHelp() {
    if (!help) return;
    final int helpSize = 16;
    final int helpX = width - helpWidth / 2;
    final String[] helpText = {
      "CONTROLS",
      "",
      "Arrow keys: Move light on XY",
      "Mouse  wheel: Move light on Z",
      "L: Reset light position to default",
      "",
      "A/W/S/D: Move model on XY",
      "+/-: Move model on Z",
      "SHIFT+mouse: Rotate model",
      "R: Reset position and rotation",
      "",
      "M: Toggle mesh (wireframe) mode",
      "V: Toggle shadow volume",
      "",
      "1: Demo spinner model",
      "2: Demo mechanism",
      "3: Generate random mechanism",
      "",
      "H: turn this help on/off",
      "P: take snapshot"
    };
    noLights();
    fill(250);
    textAlign(LEFT, TOP);
    textSize(helpSize);
    textAlign(CENTER, TOP);
    for (int i = 0; i != helpText.length; ++i) {
      text(helpText[i], helpX, 2 * i * helpSize);
    }
  }

  void drawInfo() {
    noLights();
    PVector pos = viewBox.lightPos;
    String info = "H: Help | Frame rate:" + round(frameRate) + "   Light:" + pos + " Model:" + model.pos;
    textSize(20);
    textAlign(LEFT, BOTTOM);
    fill(250);
    text(info, 10, height);
  }

  void drawModel() {
    model.draw(wireframeMode ? Model.WIREFRAME : Model.NORMAL);
  }

  boolean processKeyCode() {
    switch (keyCode) {
    case UP:   
      lightPos.y -= lightMoveSpeed; 
      break;
    case DOWN: 
      lightPos.y += lightMoveSpeed; 
      break;
    case LEFT: 
      lightPos.x -= lightMoveSpeed; 
      break;
    case RIGHT:
      lightPos.x += lightMoveSpeed;
      break;
    default:
      return false;
    }
    updateLightPos();
    return true;
  }
  
  void keyPressed() {
    if (processKeyCode()) return;
    switch (key) {
    case '1': case '2': case '3':
      resetModel(key - '0');
      break;
    case '+':
      model.pos.z += modelMoveSpeed;
      return;
    case '-': 
      model.pos.z -= modelMoveSpeed;
      return;
    case 'a': case 'A':
      model.pos.x -= modelMoveSpeed;
      return;
    case 'd': case 'D':
      model.pos.x += modelMoveSpeed;
      return;
    case 'w': case'W': 
      model.pos.y -= modelMoveSpeed;
      return;
    case 's': case 'S':
      model.pos.y += modelMoveSpeed;
      return;
    case 'l': case 'L': 
      resetLight();
      break;
    case 'r': case 'R':
      model.reset(); 
      break;
    case 'v': case 'V':
      shadowMode ^= true; 
      break;
    case 'm': case 'M':
      wireframeMode ^= true; 
      break;
    }
    key = 0;
  }

  void resetModel() {
    resetModel(modelType);
  }
  
  void resetModel(int type) {
    switch (type) {
    case 1:
      model = new SpinnerModel();
      break;
    case 2:
      model = new TestMechanism();
      break;
    case 3:
      model = new RandomMechanism();
      break;
    default: assert false;
    }
    modelType = type;
    model.reset();
    resetLight();
  }
  
  void mouseMoved() {
    if (keyPressed && keyCode == KEY_MODEL) {
      model.rot.add((pmouseY - mouseY) * rotSpeed, (mouseX - pmouseX) * rotSpeed, 0);
    }
  }

  void mouseWheel(MouseEvent e) {
    if (keyPressed && keyCode == KEY_MODEL) {
      model.rot.z -= e.getCount() * rotSpeed;
    } else {
      lightPos.z -= lightMoveSpeed * e.getCount() / 2;
      updateLightPos();
    }
  }

  void resetLight() {
    lightPos.set((right + left)/2, -height, 2 * front);
    updateLightPos();
  }

  void setBounds() {
    left = top = 0;
    bottom = height - 30;
    if (help) {
      right = width - helpWidth;
    }
    else {
      right = width;
    }
    back = -width/2.0;
    front = width/2.0;
    box = makeBox(right - left, bottom - top, (front - back), tintAndFlipVertical(boxImg), false);
  }

  void update() {
    model.update();
    if (keyPressed) keyPressed();
  }

  void updateLightPos() {
    PVector p = new PVector();
    getMatrix().mult(lightPos, p);
    volume.set("lightPos", p);
  }

  Model   model;
  float   left = 0, right = 0, top = 0, bottom = 0, front = 0, back = 0;
  PVector camera = new PVector();
  PVector lightPos = new PVector();
  PVector lightModelViewBoxPos = new PVector();
  float   rotSpeed = 0.005, modelMoveSpeed = 5, lightMoveSpeed = 20;
  PShader volume = loadShader("volume_shader_frag.glsl", "volume_shader_vert.glsl");
  PShape  box;
//  PImage  boxImg = loadImage("orloje-v-praze.jpg");
  PImage  boxImg = loadImage("diagram.jpg");
  boolean shadowMode = true, wireframeMode = false;
}
