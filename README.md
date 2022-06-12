An AmigaOS datatype for the Quite OK Image Format
=================================================

![Screenshot](https://raw.githubusercontent.com/dgaw/qoi-datatype/master/screenshot.png)

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

* 0.6 (2022-06-12) - Initial release

Issues
------

If you find any bugs or issues, please report them here:
https://github.com/dgaw/qoi-datatype/issues

Credits
-------

* This datatype is based on samplePNM.datatype by Andreas R. Kleinert.
  Available at: http://aminet.net/package/dev/c/C_V43-DT

* I used source code from the reference QOI decoder by Dominic Szablewski.
  Available at: https://github.com/phoboslab/qoi

* MakeDT.rexx script by Michal Letowski is used in the build process.
  Available at: http://aminet.net/package/dev/misc/MakeDT-1.3

License
-------

Relased under the MIT License.

Source code
-----------

Source code is available at:
https://github.com/dgaw/qoi-datatype

Built with SAS/C 6.50.
