//
//  GameViewController.swift
//  Magic
//
//  Created by mengyun on 16/1/30.
//  Copyright © 2016年 mengyun. All rights reserved.
//

import GLKit
import OpenGLES

let shaderGLK=1    //GLKBaseEffect着色器开关,==1则打开
let shaderES2=1    //可编程着色器开关,＝=1则打开

func BUFFER_OFFSET(i: Int) -> UnsafePointer<Void> {
    let p: UnsafePointer<Void> = nil
    return p.advancedBy(i)
}

let UNIFORM_MODELVIEWPROJECTION_MATRIX = 0
let UNIFORM_NORMAL_MATRIX = 1
var uniforms = [GLint](count: 2, repeatedValue: 0)

class GameViewController: GLKViewController {
    
    var program: GLuint = 0
    
    var modelViewProjectionMatrix:GLKMatrix4 = GLKMatrix4Identity
    var normalMatrix: GLKMatrix3 = GLKMatrix3Identity
    var rotation: Float = 0.0
    
    var vertexArray: GLuint = 0
    var vertexBuffer: GLuint = 0
    
    var context: EAGLContext? = nil
    var effect: GLKBaseEffect? = nil
    
    deinit {
        self.tearDownGL()
        
        if EAGLContext.currentContext() === self.context {
            EAGLContext.setCurrentContext(nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.context = EAGLContext(API: .OpenGLES2)
        
        if !(self.context != nil) {
            print("Failed to create ES context")
        }
        
        let view = self.view as! GLKView
        view.context = self.context!
        view.drawableDepthFormat = .Format24
        
        self.setupGL()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        if self.isViewLoaded() && (self.view.window != nil) {
            self.view = nil
            
            self.tearDownGL()
            
            if EAGLContext.currentContext() === self.context {
                EAGLContext.setCurrentContext(nil)
            }
            self.context = nil
        }
    }
    
    func setupGL() {
        EAGLContext.setCurrentContext(self.context)
        
        if shaderES2==1{
            self.loadShaders()
        }
        if shaderGLK==1 {
            self.effect = GLKBaseEffect()
            self.effect!.light0.enabled = GLboolean(GL_TRUE)
            self.effect!.light0.diffuseColor = GLKVector4Make(1.0, 0.4, 0.4, 1.0)
        }
        
        glEnable(GLenum(GL_DEPTH_TEST))
        
        glGenVertexArraysOES(1, &vertexArray)
        glBindVertexArrayOES(vertexArray)
        
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(sizeof(GLfloat) * gCubeVertexData.count), &gCubeVertexData, GLenum(GL_STATIC_DRAW))
        
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue))
        glVertexAttribPointer(GLuint(GLKVertexAttrib.Position.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, BUFFER_OFFSET(0))
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Normal.rawValue))
        glVertexAttribPointer(GLuint(GLKVertexAttrib.Normal.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, BUFFER_OFFSET(12))
        
        glBindVertexArrayOES(0)
    }
    
    func tearDownGL() {
        EAGLContext.setCurrentContext(self.context)
        
        glDeleteBuffers(1, &vertexBuffer)
        glDeleteVertexArraysOES(1, &vertexArray)
        
        self.effect = nil
        
        if program != 0 {
            glDeleteProgram(program)
            program = 0
        }
    }
    
    // MARK: - GLKView and GLKViewController delegate methods
    
    func update() {
        let aspect = fabsf(Float(self.view.bounds.size.width / self.view.bounds.size.height))
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0), aspect, 0.1, 100.0)
        
        var baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, -4.0)
        baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, 0.0, 0.0, 1.0, 0.0)
        
        var modelViewMatrix:GLKMatrix4
        
        // Compute the model view matrix for the object rendered with GLKit
        if shaderGLK==1{
            self.effect?.transform.projectionMatrix = projectionMatrix
            modelViewMatrix = GLKMatrix4MakeTranslation(0.0, 1.0, 0.0)
            modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, -rotation, 0.0, 1.0, 0.0)
            modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix)
            self.effect?.transform.modelviewMatrix = modelViewMatrix
        }
        
        // Compute the model view matrix for the object rendered with ES2
        if shaderES2==1{
            modelViewMatrix = GLKMatrix4MakeTranslation(0.0, -1.0, 0.0)
            modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, rotation, 0.0, 1.0, 0.0)
            modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix)
            normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), nil)
            modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
        }
        rotation += 0.015//Float(self.timeSinceLastUpdate * 0.5)
    }
    
    override func glkView(view: GLKView, drawInRect rect: CGRect) {
        glClearColor(0.65, 0.65, 0.65, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        
        glBindVertexArrayOES(vertexArray)
        
        // Render the object with GLKit
        if shaderGLK==1 {
            self.effect?.prepareToDraw()
            glDrawArrays(GLenum(GL_TRIANGLES) , 0, 36)
        }
        
        // Render the object again with ES2
        if shaderES2==1{
            glUseProgram(program)
            withUnsafePointer(&modelViewProjectionMatrix, {
                glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafePointer($0))
            })
            
            withUnsafePointer(&normalMatrix, {
                glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, UnsafePointer($0))
            })
            
            glDrawArrays(GLenum(GL_TRIANGLES), 0, 36)
        }
    }
    
    // MARK: -  OpenGL ES 2 shader compilation
    //loadShaders()步骤：
    //1.创建程序。
    //2.创建并编译顶点着色器和片段着色器。
    //3.把 顶点着色器和片段着色器 与 程序连接起来。
    //4.设置 顶点着色器和片段着色器 的输入参数。
    //5.链接程序。
    //6.获取 uniform 指针。
    //注意：这步只能在5成功后才能调用，在linkProgrom前，uniform位置是不确定的。
    //7.断开 顶点着色器和片段着色器 ，并释放它们。
    //注意：程序并没释放。
    //
    //第4步是会变化的部分，第6步为可选。
    func loadShaders() -> Bool {
        var vertShader: GLuint = 0
        var fragShader: GLuint = 0
        var vertShaderPathname: String
        var fragShaderPathname: String
        
        //创建程序.
        program = glCreateProgram()
        
        //创建并编译顶点着色器.
        vertShaderPathname = NSBundle.mainBundle().pathForResource("Shader", ofType: "vsh")!
        if self.compileShader(&vertShader, type: GLenum(GL_VERTEX_SHADER), file: vertShaderPathname) == false {
            print("Failed to compile vertex shader")
            return false
        }
        //创建并编译片段着色器.
        fragShaderPathname = NSBundle.mainBundle().pathForResource("Shader", ofType: "fsh")!
        if !self.compileShader(&fragShader, type: GLenum(GL_FRAGMENT_SHADER), file: fragShaderPathname) {
            print("Failed to compile fragment shader")
            return false
        }
        
        //把顶点着色器与程序连接起来.
        glAttachShader(program, vertShader)
        //把片段着色器与程序连接起来.
        glAttachShader(program, fragShader)

        //设置 顶点着色器和片段着色器 的输入参数。
        //"position"和"normal"与着色器代码Shader.vsh里面的2个attribute对应，
        //分别与setupGL加载的顶点数组里面的顶点和法线数据对应起来。
        glBindAttribLocation(program, GLuint(GLKVertexAttrib.Position.rawValue), "position")
        glBindAttribLocation(program, GLuint(GLKVertexAttrib.Normal.rawValue), "normal")
        
        //链接程序.
        if !self.linkProgram(program) {
            print("Failed to link program: \(program)")
            
            if vertShader != 0 {
                glDeleteShader(vertShader)
                vertShader = 0
            }
            if fragShader != 0 {
                glDeleteShader(fragShader)
                fragShader = 0
            }
            if program != 0 {
                glDeleteProgram(program)
                program = 0
            }
            
            return false
        }
        
        //获取 uniform 指针.
        uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(program, "modelViewProjectionMatrix")
        uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(program, "normalMatrix")
        
        //释放着色器
        if vertShader != 0 {
            glDetachShader(program, vertShader)
            glDeleteShader(vertShader)
        }
        if fragShader != 0 {
            glDetachShader(program, fragShader)
            glDeleteShader(fragShader)
        }
        
        return true
    }
    
    
    func compileShader(inout shader: GLuint, type: GLenum, file: String) -> Bool {
        var status: GLint = 0
        var source: UnsafePointer<Int8>
        do {
            source = try NSString(contentsOfFile: file, encoding: NSUTF8StringEncoding).UTF8String
        } catch {
            print("Failed to load vertex shader")
            return false
        }
        var castSource = UnsafePointer<GLchar>(source)
        
        shader = glCreateShader(type)
        glShaderSource(shader, 1, &castSource, nil)
        glCompileShader(shader)
        
        //#if defined(DEBUG)
        //        var logLength: GLint = 0
        //        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        //        if logLength > 0 {
        //            var log = UnsafeMutablePointer<GLchar>(malloc(Int(logLength)))
        //            glGetShaderInfoLog(shader, logLength, &logLength, log)
        //            NSLog("Shader compile log: \n%s", log)
        //            free(log)
        //        }
        //#endif
        
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
        if status == 0 {
            glDeleteShader(shader)
            return false
        }
        return true
    }
    
    func linkProgram(prog: GLuint) -> Bool {
        var status: GLint = 0
        glLinkProgram(prog)
        
        //#if defined(DEBUG)
        //        var logLength: GLint = 0
        //        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        //        if logLength > 0 {
        //            var log = UnsafeMutablePointer<GLchar>(malloc(Int(logLength)))
        //            glGetShaderInfoLog(shader, logLength, &logLength, log)
        //            NSLog("Shader compile log: \n%s", log)
        //            free(log)
        //        }
        //#endif
        
        glGetProgramiv(prog, GLenum(GL_LINK_STATUS), &status)
        if status == 0 {
            return false
        }
        
        return true
    }
    
    func validateProgram(prog: GLuint) -> Bool {
        var logLength: GLsizei = 0
        var status: GLint = 0
        
        glValidateProgram(prog)
        glGetProgramiv(prog, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        if logLength > 0 {
            var log: [GLchar] = [GLchar](count: Int(logLength), repeatedValue: 0)
            glGetProgramInfoLog(prog, logLength, &logLength, &log)
            print("Program validate log: \n\(log)")
        }
        
        glGetProgramiv(prog, GLenum(GL_VALIDATE_STATUS), &status)
        var returnVal = true
        if status == 0 {
            returnVal = false
        }
        return returnVal
    }
}

var gCubeVertexData: [GLfloat] = [
    // Data layout for each line below is:
    // positionX, positionY, positionZ,     normalX, normalY, normalZ,
    0.5, -0.5, -0.5,        1.0, 0.0, 0.0,
    0.5, 0.5, -0.5,         1.0, 0.0, 0.0,
    0.5, -0.5, 0.5,         1.0, 0.0, 0.0,
    0.5, -0.5, 0.5,         1.0, 0.0, 0.0,
    0.5, 0.5, -0.5,         1.0, 0.0, 0.0,
    0.5, 0.5, 0.5,          1.0, 0.0, 0.0,
    
    0.5, 0.5, -0.5,         0.0, 1.0, 0.0,
    -0.5, 0.5, -0.5,        0.0, 1.0, 0.0,
    0.5, 0.5, 0.5,          0.0, 1.0, 0.0,
    0.5, 0.5, 0.5,          0.0, 1.0, 0.0,
    -0.5, 0.5, -0.5,        0.0, 1.0, 0.0,
    -0.5, 0.5, 0.5,         0.0, 1.0, 0.0,
    
    -0.5, 0.5, -0.5,        -1.0, 0.0, 0.0,
    -0.5, -0.5, -0.5,      -1.0, 0.0, 0.0,
    -0.5, 0.5, 0.5,         -1.0, 0.0, 0.0,
    -0.5, 0.5, 0.5,         -1.0, 0.0, 0.0,
    -0.5, -0.5, -0.5,      -1.0, 0.0, 0.0,
    -0.5, -0.5, 0.5,        -1.0, 0.0, 0.0,
    
    -0.5, -0.5, -0.5,      0.0, -1.0, 0.0,
    0.5, -0.5, -0.5,        0.0, -1.0, 0.0,
    -0.5, -0.5, 0.5,        0.0, -1.0, 0.0,
    -0.5, -0.5, 0.5,        0.0, -1.0, 0.0,
    0.5, -0.5, -0.5,        0.0, -1.0, 0.0,
    0.5, -0.5, 0.5,         0.0, -1.0, 0.0,
    
    0.5, 0.5, 0.5,          0.0, 0.0, 1.0,
    -0.5, 0.5, 0.5,         0.0, 0.0, 1.0,
    0.5, -0.5, 0.5,         0.0, 0.0, 1.0,
    0.5, -0.5, 0.5,         0.0, 0.0, 1.0,
    -0.5, 0.5, 0.5,         0.0, 0.0, 1.0,
    -0.5, -0.5, 0.5,        0.0, 0.0, 1.0,
    
    0.5, -0.5, -0.5,        0.0, 0.0, -1.0,
    -0.5, -0.5, -0.5,      0.0, 0.0, -1.0,
    0.5, 0.5, -0.5,         0.0, 0.0, -1.0,
    0.5, 0.5, -0.5,         0.0, 0.0, -1.0,
    -0.5, -0.5, -0.5,      0.0, 0.0, -1.0,
    -0.5, 0.5, -0.5,        0.0, 0.0, -1.0
]
