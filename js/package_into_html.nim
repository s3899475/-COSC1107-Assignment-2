# package css and js into a single file, simply
# maybe add minification (use library?)

import std/[htmlparser, xmltree, strtabs, paths]

proc package(filename: string, out_filename: string = "out.html") =
  var html = loadHtml(filename)

  for css in html.findAll("link"):
    if css.attrs.hasKey("rel") and css.attrs.hasKey("href") and css.attrs["rel"] == "stylesheet":
      let path = css.attrs["href"].Path
      if path.isRelativeTo(paths.getCurrentDir()) and path.splitFile.ext == ".css":
        css.attrs.del "href"
        css.attrs.del "rel"
        css.tag = "style"

        var f = open(path.string, fmRead)
        css.add newText("/*")
        css.add newCData("*/\n" & f.readAll() & "\n/*")
        css.add newText("*/")
        f.close()

  for script in html.findAll("script"):
    if script.attrs.hasKey("src"):
      let path = script.attrs["src"].Path
      if path.isRelativeTo(paths.getCurrentDir()) and path.splitFile.ext == ".js":
        script.attrs.del "src"

        var f = open(path.string, fmRead)
        # add js as CDATA(unescaped data)
        # also need comments so that js still parses
        script.add newText("//")
        script.add newCData("\n" & f.readAll() & "\n//")
        f.close()

  writeFile(out_filename, $html)

when isMainModule:
  package("./page.html")
