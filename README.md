**Nyx** is a support library (gem) for Ibidem projects.

Installing

```
gem install nyx
```

You may need to have the ruby dev tools for some dependencies.

The tool is designed to be an integration tool, rather then a retrieval tool. 
While it will fetch the necesary files for you, it's main purpose is to manipulate
and clean up those files to work as desired in the system.

Nyx also serves to centralize general purpose scripting, such as javascript/scss 
build processes, watchers, etc

## Sample configuration

```json
{
	"interface": "1.0.0",

	"cores": [
		{
			"repo": "https://github.com/alademann/sass-bootstrap.git",
			"path": "src/vendor/twbs",
			"version": "v3.0.0_sass",
			"keep": ["sass", "fonts", "README.md", "LICENSE"]
		},
		{
			"repo": "https://github.com/FortAwesome/Font-Awesome.git",
			"path": "src/vendor/fontawesome",
			"version": "v3.2.1",
			"keep": ["scss", "font", "README.md"]
		}
	]
}
```

## Quick Reference

You can get a list of all commands by just invoking `nyx` with no parameters.

*General functions*

 - dependency (ie. core) integration management (nyx compile)

*Other functions*

 - script compilation (Nyx.new.compile_scripts)
 - script watch (Nyx.new.watch_scripts)
 - style compilation (Nyx.new.compile_style)
 - style watch (Nyx.new.watch_style)

