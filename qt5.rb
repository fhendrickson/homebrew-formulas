require "formula"

class Qt5HeadDownloadStrategy < GitDownloadStrategy
  include FileUtils

  def stage
    @clone.cd { reset }
    safe_system "git", "clone", @clone, "."
    ln_s @clone, "qt"
    safe_system "./init-repository", "--mirror", "#{Dir.pwd}/"
    rm "qt"
  end
end

class Qt5 < Formula
  homepage "http://qt-project.org/"
  url "http://download.qt-project.org/official_releases/qt/5.3/5.3.2/single/qt-everywhere-opensource-src-5.3.2.tar.gz"
  sha1 "502dd2db1e9ce349bb8ac48b4edf7f768df1cafe"

  head "git://gitorious.org/qt/qt5.git", :branch => "stable",
    :using => Qt5HeadDownloadStrategy, :shallow => false
    
  bottle do
    root_url 'http://hifi-public.s3.amazonaws.com/dependencies/qt'
    revision 1
    sha1 "5be505fa4867c7932bf52d99d4e2805209ed0401" => :mavericks
  end

  keg_only "Qt 5 conflicts Qt 4 (which is currently much more widely used)."

  option :universal
  option "with-docs", "Build documentation"
  option "developer", "Build and link with developer options"

  depends_on "pkg-config" => :build
  depends_on "d-bus" => :optional
  depends_on "mysql" => :optional
  depends_on :xcode => :build
  
  # fix exclusion of QT_NO_BEARER_MANAGEMENT in qcorewlanegine.mm
  patch do
    url 'https://gist.githubusercontent.com/birarda/5c3e0f4979279eb6c959/raw/10f841822398f3dfa1122b6726879acc06a13bde/gistfile1.txt'
    sha1 'b0fa7810264783c07672ba73a342d832d3e6a29a' 
  end

  def install
    ENV.universal_binary if build.universal?
    args = ["-prefix", prefix,
            "-system-zlib",
            "-qt-libpng", "-qt-libjpeg",
            "-confirm-license", "-opensource",
            "-nomake", "examples",
            "-nomake", "tests",
            "-skip", "qtenginio",
            "-release"]

    # https://bugreports.qt-project.org/browse/QTBUG-34382
    args << "-no-xcb"

    args << "-plugin-sql-mysql" if build.with? "mysql"

    if build.with? "d-bus"
      dbus_opt = Formula["d-bus"].opt_prefix
      args << "-I#{dbus_opt}/lib/dbus-1.0/include"
      args << "-I#{dbus_opt}/include/dbus-1.0"
      args << "-L#{dbus_opt}/lib"
      args << "-ldbus-1"
      args << "-dbus-linked"
    end

    if MacOS.prefer_64_bit? or build.universal?
      args << "-arch" << "x86_64"
    end

    if !MacOS.prefer_64_bit? or build.universal?
      args << "-arch" << "x86"
    end

    args << "-developer-build" if build.include? "developer"
    
    ENV.append 'CXXFLAGS', '-DQT_NO_BEARER_MANAGEMENT'
    args << "-no-feature-bearermanagement"

    system "./configure", *args
    system "make"
    ENV.j1
    system "make install"
    if build.with? "docs"
      system "make", "docs"
      system "make", "install_docs"
    end

    # Some config scripts will only find Qt in a "Frameworks" folder
    frameworks.install_symlink Dir["#{lib}/*.framework"]

    # The pkg-config files installed suggest that headers can be found in the
    # `include` directory. Make this so by creating symlinks from `include` to
    # the Frameworks' Headers folders.
    Pathname.glob("#{lib}/*.framework/Headers") do |path|
      include.install_symlink path => path.parent.basename(".framework")
    end

    # configure saved the PKG_CONFIG_LIBDIR set up by superenv; remove it
    # see: https://github.com/Homebrew/homebrew/issues/27184
    inreplace prefix/"mkspecs/qconfig.pri", /\n\n# pkgconfig/, ""
    inreplace prefix/"mkspecs/qconfig.pri", /\nPKG_CONFIG_.*=.*$/, ""

    Pathname.glob("#{bin}/*.app") { |app| mv app, prefix }
  end

  test do
    system "#{bin}/qmake", "-project"
  end

  def caveats; <<-EOS.undent
    We agreed to the Qt opensource license for you.
    If this is unacceptable you should uninstall.
    EOS
  end
end