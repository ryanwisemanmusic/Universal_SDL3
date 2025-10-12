#!/bin/bash

BREW_PREFIX=$(brew --prefix)
SDL3_PATH=$(brew --prefix sdl3 2>/dev/null || echo "/opt/homebrew")

cat > .vscode/c_cpp_properties.json << EOF
{
    "configurations": [
        {
            "name": "Mac", 
            "includePath": [
                "\${default}",
                "$SDL3_PATH/include",
                "$BREW_PREFIX/include"
            ],
            "defines": [],
            "cStandard": "c17", 
            "cppStandard": "c++17"
        }
    ],
    "version": 4
}
EOF

echo "Generated c_cpp_properties.json with SDL3 path: $SDL3_PATH/include"