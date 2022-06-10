Short: Datatype for the Quite OK Image Format (.qoi files)
Type: util/dtype
Version: 0.9
Uploader: d.ami.angaweda@gmail.com (Damian Gaweda)
Author: d.ami.angaweda@gmail.com (Damian Gaweda)
Architecture: m68k-amigaos
Requires: OS 3.0+,picture.datatype v43

An AmigaOS datatype for the Quite OK Image Format (.qoi files)
==============================================================

QOI is a fast, lossless image compression format. QOI files are
similar in size to PNG while offering much faster encoding
and decoding.

Download example images to try out with this datatype:
https://qoiformat.org/qoi_test_images.zip

Read more about the format on https://qoiformat.org.

Requirements
------------

* AmigaOS 3.0+ (tested on 3.1)
* picture.datatype V43 (tested with V43.41 on RTG and AGA)

Changes
-------

* 0.9 (2022-06-01) - Initial release

Credits
-------

* This datatype is based on samplePNM.datatype by Andreas R. Kleinert.
  Available at: http://aminet.net/package/dev/c/C_V43-DT

* I used source code from the reference QOI decoder by the author
  of the QOI format: Dominic Szablewski
  Available at: https://github.com/phoboslab/qoi

* MakeDT.rexx script by Michal Letowski is used in the build process.
  Available at: http://aminet.net/package/dev/misc/MakeDT-1.3

License
-------

Relased under the MIT License.

Source code
-----------

Source code is available at:
https://github.com/dgaw/qoi-datatype [TODO: create repo]
