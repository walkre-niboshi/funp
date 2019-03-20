import os, osproc, ospaths, json, strscans, strutils
import docopt

proc removeFromJson(jsonNode: JsonNode, target: string): JsonNode =
  if jsonNode.kind == JObject:
    if jsonNode.contains("name") and jsonNode["name"].getStr() == target: return nil

    result = newJObject()
    for key, child in jsonNode.getFields().pairs:
      let childResult = child.removeFromJson(target)
      if childResult == nil: continue

      result.add(key, child.removeFromJson(target))

  elif jsonNode.kind == JArray:
    result = newJArray()
    for child in jsonNode.items:
      let childResult = child.removeFromJson(target)
      if childResult == nil: continue

      result.add(child.removeFromJson(target))
  else: return jsonNode

proc promptContinuing() =
  echo("Do you wish to continue? [y/N]")
  let answer = readLine(stdin)
  if answer != "y": quit()

proc removeBinary(packageName, nimblePath: string) =
  # Remove from bin directory
  let binaryPath = nimblePath / "/bin/" / packageName
  try:
    removeFile(binaryPath)
    echo("Successfully removed the binary file: " & binaryPath)
  except IOError:
    echo("Failed to remove the binary file: " & binaryPath)
    promptContinuing()

proc removeFromNimbleDataJson(packageName, nimblePath: string) =
  # Remove from nimbledata.json
  let
    nimbleDataJsonPath = nimblePath / "nimbledata.json"
    jsonNode = parseFile(nimblePath / "nimbledata.json")
  try:
    let
     packageRemovedJson = jsonNode.removeFromJson(packageName).pretty()
    writeFile(nimbleDataJsonPath, packageRemovedJson)
    echo("Successfully removed from nimbledata.json: " & nimbleDataJsonPath)
  except JsonParsingError, IOError:
    echo("Failed to remove from nimbledata.json: " & nimbleDataJsonPath)
    promptContinuing()

proc removePackageDirectories(packageName, nimblePath: string) =
  # Remove from pkgs directory
  let pkgsDirectory = nimblePath / "pkgs"
  for kind, path in walkDir(pkgsDirectory):
    if kind != PathComponent.pcDir: continue

    let directoryName = path.extractFilename
    if not directoryName.startsWith(packageName & "-"): continue

    let versionInfo = directoryName.substr(packageName.len)
    var v1, v2, v3: int
    if scanf(versionInfo, "$i.$i.$i", v1, v2, v3):
      try:
        removeDir(path)
        echo("Successfully removed a package directory: " & path)
      except IOError:
        echo("Failed to remove a package directory: " & path)
        promptContinuing()

const doc = """
Usage:
  nimblecleaner [--backup=<directory>] <package-name>
  nimblecleaner (-h | --help)
  nimblecleaner --version

Options:
  -h --help             Show this help message.
  --version             Show version.
  --backup=<directory>  Back up 'nimbledata.json' to the directory before removal.
"""

let args = docopt(doc)

if args["--version"]:
  echo("nimblecleaner 0.1.1")
elif args["<package-name>"]:
  let
    packageName = $args["<package-name>"]
    nimblePath = execProcess("nimble path " & packageName).parentDir.parentDir

  if args["--backup"]:
   try:
     let nimbleDataJsonPath = nimblePath / "nimbledata.json"
     copyFile(nimbleDataJsonPath, $args["--backup"] / "nimbledata.json")
   except OSError:
     echo("Failed to back up 'nimbledata.json'. Process cancelled.")
     quit()
 
  removeBinary(packageName, nimblePath)
  removeFromNimbleDataJson(packageName, nimblePath)
  removePackageDirectories(packageName, nimblePath)
