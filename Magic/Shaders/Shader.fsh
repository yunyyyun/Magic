//
//  Shader.fsh
//  Magic
//
//  Created by mengyun on 16/1/30.
//  Copyright © 2016年 mengyun. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
