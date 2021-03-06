require 'formula'

class H5utils < Formula
  homepage 'http://ab-initio.mit.edu/wiki/index.php/H5utils'
  url 'http://ab-initio.mit.edu/h5utils/h5utils-1.12.1.tar.gz'
  sha1 '1bd8ef8c50221da35aafb5424de9b5f177250d2d'

  depends_on :libpng
  depends_on 'hdf5'

  # A patch is required in order to build h5utils with libpng 1.5
  patch :p0 do
    url "https://trac.macports.org/export/102291/trunk/dports/science/h5utils/files/patch-writepng.c"
    sha1 "026aa59f2e13388d0b7834de6dcbd48da2858cbe"
  end

  def install
    system "./configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--without-octave"
    system "make install"
  end
end
