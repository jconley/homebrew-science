require 'formula'

class PyQtImportable < Requirement
  fatal true
  default_formula "pyqt"
  satisfy :build_env => true do
    quiet_system 'python', '-c', 'from PyQt import QtCore'
  end

  def message
    <<-EOS.undent
      Python could not import the PyQt4 module. This will cause the QGIS build to fail.
      The most common reason for this failure is that the PYTHONPATH needs to be adjusted.
    EOS
  end
end

class Psycopg2Importable < Requirement
  fatal false
  satisfy do
    ENV["PYTHONPATH"] ||= Formula["python"].site_packages
    quiet_system 'python', '-c', 'import psycopg2'
  end

  def message
    <<-EOS.undent
      qgis will throw startup warnings without the python module psycopg2. install using:
        pip install psycopg2
    EOS
  end
end

class Qgis < Formula
  homepage 'http://www.qgis.org'
  url "http://qgis.org/downloads/qgis-2.4.0.tar.bz2"
  sha256 "711b7d81ddff45b083a21f05c8aa5093a6a38a0ee42dfcc873234fcef1fcdd76"

  head 'https://github.com/qgis/Quantum-GIS.git', :branch => 'master'

  depends_on "bison" => :build
  depends_on 'cmake' => :build

  depends_on "gsl" => :recommended
  depends_on 'qwt'
  depends_on 'expat'
  depends_on 'gdal'
  depends_on 'proj'
  depends_on 'spatialindex'
  depends_on 'grass' => :optional
  depends_on "postgresql" => :recommended
  depends_on "qwtpolar"
  depends_on "sqlite"

  depends_on :python
  depends_on "numpy" => :recommended
  depends_on "qscintilla2"
  depends_on "pyqt"
  depends_on PyQtImportable
  depends_on Psycopg2Importable

  def install
    # Set bundling level back to 0 (the default in all versions prior to 1.8.0)
    # so that no time and energy is wasted copying the Qt frameworks into QGIS.
    # use external qwtpolar as bundled version is not compatible with latest qwt 6.1.0
    args = std_cmake_args.concat %W[
      -DQWT_INCLUDE_DIR=#{Formula["qwt"].opt_prefix}/lib/qwt.framework/Headers/
      -DQWT_LIBRARY=#{Formula["qwt"].opt_prefix}/lib/qwt.framework/qwt
      -DBISON_EXECUTABLE=#{Formula["bison"].opt_prefix}/bin/bison
      -DENABLE_TESTS=NO
      -DWITH_INTERNAL_QWTPOLAR=NO
      -DQWTPOLAR_INCLUDE_DIR=#{Formula["qwtpolar"].opt_prefix}/lib/qwtpolar.framework/Headers
      -DQWTPOLAR_LIBRARY=#{Formula["qwtpolar"].opt_prefix}/lib/qwtpolar.framework/qwtpolar
      -DQGIS_MACAPP_BUNDLE=0
      -DQGIS_MACAPP_DEV_PREFIX='#{frameworks}'
      -DQGIS_MACAPP_INSTALL_DEV=YES
      -DPYTHON_LIBRARY='#{%x(python-config --prefix).chomp}/lib/libpython2.7.dylib'
    ]

    args << "-DWITH_POSTGRESQL=#{build.with?("postgresql") ? "ON" : "OFF"}"
    args << "-DWITH_GRASS=#{build.with?("grass") ? "ON" : "OFF"}"

    if build.with? "grass"
      args << "-DGRASS_PREFIX='#{Formula["grass"].opt_prefix}'"
      # So that `libintl.h` can be found
      ENV.append 'CXXFLAGS', "-I'#{Formula["gettext"].opt_prefix}/include'"
    end

    # Avoid ld: framework not found QtSql (https://github.com/Homebrew/homebrew-science/issues/23)
    ENV.append 'CXXFLAGS', "-F#{Formula["qt"].opt_prefix}/lib"

    Dir.mkdir 'build'
    Dir.chdir 'build' do
      system 'cmake', '..', *args
      system 'make install'
    end

    py_lib = lib/"python2.7/site-packages"
    qgis_modules = prefix + 'QGIS.app/Contents/Resources/python/qgis'
    py_lib.mkpath
    ln_s qgis_modules, py_lib + 'qgis'

    # Create script to launch QGIS app
    (bin + 'qgis').write <<-EOS.undent
      #!/bin/sh
      # Ensure Python modules can be found when QGIS is running.
      env PATH='#{HOMEBREW_PREFIX}/bin':$PATH PYTHONPATH='#{Formula["python"].site_packages}':$PYTHONPATH\\
        open #{prefix}/QGIS.app
    EOS
  end

  def caveats
    <<-EOS.undent
      if you get startup warnings about loading plugin 'processing', you should install psycopg2:
        pip install psycopg2

      QGIS has been built as an application bundle. To make it easily available, a
      wrapper script has been written that launches the app with environment
      variables set so that Python modules will be functional:

        qgis

      You may also symlink QGIS.app into ~/Applications:
        brew linkapps
        mkdir -p #{ENV['HOME']}/.MacOSX
        defaults write #{ENV['HOME']}/.MacOSX/environment.plist PYTHONPATH -string "#{Formula["python"].site_packages}"

      You will need to log out and log in again to make environment.plist effective.

    EOS
  end
end
