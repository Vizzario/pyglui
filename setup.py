from __future__ import print_function
import os, platform
from stat import ST_MTIME
import numpy

if platform.system() == 'Windows':
    from setuptools import setup, Extension
else:
    from distutils.core import setup
    from distutils.extension import Extension

from Cython.Build import cythonize

from pyglui.cygl.glew_pxd import generate_pxd

includes = ['pyglui/cygl/', '.', numpy.get_include()]
glew_binaries =[]
lib_dir = []
fontstash_compile_args = ['-D FONTSTASH_IMPLEMENTATION','-D GLFONTSTASH_IMPLEMENTATION']

if platform.system() == 'Darwin':
    # find glew irrespective of version
    for search_dir in ['/usr/local/Cellar/glew', '/opt/local/include']:
        for root, dirs, files in os.walk(search_dir):
            if 'glew.h' in files:
                glew_header = os.path.join(root,'glew.h')
                includes.append(search_dir)
    includes += ['/System/Library/Frameworks/OpenGL.framework/Versions/Current/Headers/', '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/OpenGL.framework/Headers/']
    link_args = []
    libs = ['GLEW']
    libglew = [] #we are using the dylib
    extra_compile_args = ["-Wno-strict-aliasing", "-O2"]
elif platform.system() == 'Linux':
    glew_header = '/usr/include/GL/glew.h'
    includes += ['/usr/include/GL']
    libs = ['GLEW','GL'] #GL needed for fonstash
    link_args = []
    extra_compile_args = ["-Wno-strict-aliasing", "-O2"]
elif platform.system() == 'Windows':
    glew_header = 'pyglui/cygl/win_glew/gl/glew.h'
    includes += ['pyglui/cygl/win_glew']
    libs = ['glew32', 'OpenGL32']
    lib_dir = ['pyglui/cygl/win_glew']
    link_args = []
    gl_compile_args = [] #['/DGL_GLEXT_PROTOTYPES']
    extra_compile_args = ["-O2"]
    fontstash_compile_args = ['/DFONTSTASH_IMPLEMENTATION','/DGLFONTSTASH_IMPLEMENTATION']
    glew_binaries = [('', ['pyglui/cygl/win_glew/glew32.dll'])]
else:
    raise Exception('Platform build not implemented.')


if os.path.isfile('pyglui/cygl/glew.pxd') and os.stat('pyglui/cygl/glew.pxd')[ST_MTIME] > os.stat(glew_header)[ST_MTIME]:
    print("'glew.pxd' is up-to-date.")
else:
    print("generating glew.pxd based on '%s'"%glew_header)
    generate_pxd(glew_header,'pyglui/cygl')


extensions = [
	Extension(	name="pyglui.ui",
				sources=['pyglui/ui.pyx'],
				include_dirs = includes+['pyglui/pyfontstash/fontstash/src'],
				libraries = libs,
				library_dirs = lib_dir,
				extra_link_args=link_args,
				extra_compile_args=extra_compile_args,
                language="c++"),

	Extension(	name="pyglui.graph",
				sources=['pyglui/graph.pyx'],
				include_dirs = includes+['pyglui/pyfontstash/fontstash/src'],
				libraries = libs,
				library_dirs = lib_dir,
				extra_link_args=link_args,
				extra_compile_args=extra_compile_args,
                language="c++"),

	Extension(	name="pyglui.cygl.utils",
				sources=['pyglui/cygl/utils.pyx'],
				include_dirs = includes,
				libraries = libs,
				library_dirs = lib_dir,
				extra_link_args=link_args,
				extra_compile_args=extra_compile_args,
                language="c++"),

	Extension(	name="pyglui.cygl.shader",
				sources=['pyglui/cygl/shader.pyx'],
				include_dirs = includes,
				libraries = libs,
				library_dirs = lib_dir,
				extra_link_args=link_args,
				extra_compile_args=extra_compile_args,
                language="c++"),

	Extension(	name="pyglui.pyfontstash.fontstash",
				sources=['pyglui/pyfontstash/fontstash.pyx'],
				include_dirs = includes+['pyglui/pyfontstash/fontstash/src'],
				libraries = libs,
				library_dirs = lib_dir,
				extra_link_args=link_args,
				extra_compile_args=extra_compile_args+fontstash_compile_args)
]

from pyglui import __version__ as pyglui_version
# from pyglui.pyfontstash import __version__ as fs_version
# from pyglui.cygl import __version__ as cygl_version



setup( 	name="pyglui",
		version=pyglui_version,
		packages = ['pyglui'],
		py_modules = ['pyglui.cygl.__init__','pyglui.pyfontstash.__init__'], #add  __init__.py files
		description="OpenGL UI powered by Cython",
		url="https://github.com/pupil-labs/pyglui",
		author='Pupil Labs',
		author_email='info@pupil-labs.com',
		license='MIT',
		data_files=glew_binaries,
        package_dir={'pyglui':'pyglui'},
        package_data={'pyglui': ['*.ttf']}, #fonts
		ext_modules=cythonize(extensions)
)
