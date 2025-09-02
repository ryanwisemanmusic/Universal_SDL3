In general, if you are running into issues involving a lack of CMake finding
your libraries, there is a way to hyperspecify things, generating a manifest
file. This will mark everything needed for CMake to be satisfies (at least should be satisfied anyway
because fuck CMake)

An example of a manifest file in the debugger:

FOP manifest created:
{
    "version": "2.11",
    "install_path": "/lilyspark/opt/lib/java/fop",
    "jar_count": 30,
    "classpath": "/lilyspark/opt/lib/java/fop/lib/xmlgraphics-commons-2.11.jar:/lilyspark/opt/lib/java/fop/lib/pdfbox-io-3.0.3.jar:/lilyspark/opt/lib/java/fop/lib/batik-svggen-1.19.jar:/lilyspark/opt/lib/java/fop/lib/commons-logging-1.3.0.jar:/lilyspark/opt/lib/java/fop/lib/batik-svg-dom-1.19.jar:/lilyspark/opt/lib/java/fop/lib/fop-events-2.11.jar:/lilyspark/opt/lib/java/fop/lib/batik-shared-resources-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-script-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-extension-1.19.jar:/lilyspark/opt/lib/java/fop/lib/fontbox-3.0.3.jar:/lilyspark/opt/lib/java/fop/lib/fop-2.11.jar:/lilyspark/opt/lib/java/fop/lib/batik-constants-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-xml-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-css-1.19.jar:/lilyspark/opt/lib/java/fop/lib/xml-apis-ext-1.3.04.jar:/lilyspark/opt/lib/java/fop/lib/fop-util-2.11.jar:/lilyspark/opt/lib/java/fop/lib/batik-bridge-1.19.jar:/lilyspark/opt/lib/java/fop/lib/fop-core-2.11.jar:/lilyspark/opt/lib/java/fop/lib/batik-codec-1.19.jar:/lilyspark/opt/lib/java/fop/lib/xml-apis-1.4.01.jar:/lilyspark/opt/lib/java/fop/lib/commons-io-2.17.0.jar:/lilyspark/opt/lib/java/fop/lib/batik-awt-util-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-parser-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-transcoder-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-ext-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-i18n-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-anim-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-gvt-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-util-1.19.jar:/lilyspark/opt/lib/java/fop/lib/batik-dom-1.19.jar",
    "launcher": "/lilyspark/opt/lib/java/fop/bin/fop",
    "status": "installed"
}

You are likely to see, if things get fucked, a lack of good classpath or launcher.
Keep in mind, we will have to wrap Windows .bat files to UNIX standards, because
there are some libraries that don't give Alpine Linux a nice time.