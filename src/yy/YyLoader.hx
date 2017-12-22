package yy;
import ace.AceWrap.AceAutoCompleteItem;
import electron.FileSystem;
import gml.GmlAPI;
import gml.Project;
import gml.GmlSeeker;
import haxe.io.Path;
import js.html.Element;
import tools.Dictionary;
import ui.TreeView;

/**
 * ...
 * @author YellowAfterlife
 */
class YyLoader {
	public static function run(project:Project):String {
		var dir = project.dir;
		var yyProject:YyProject = FileSystem.readJsonFileSync(project.path);
		var resources:Dictionary<YyProjectResource> = new Dictionary();
		var views:Dictionary<YyView> = new Dictionary();
		var rootView:YyView = null;
		for (res in yyProject.resources) {
			var key = res.Key;
			resources.set(key, res);
			var val = res.Value;
			if (val.resourceType == "GMFolder") {
				var view:YyView = FileSystem.readJsonFileSync(Path.join([dir, val.resourcePath]));
				if (view.isDefaultView) rootView = view;
				views.set(key, view);
			}
		}
		if (rootView == null) return "Couldn't find a top-level view in project.";
		//
		GmlAPI.gmlClear();
		var comp = GmlAPI.gmlComp;
		//
		var rxName = ~/^.+[\/\\](\w+)\.\w+$/g;
		var objectNames = new Dictionary<String>();
		var objectGUIDs = new Dictionary<YyGUID>();
		project.yyObjectNames = objectNames;
		project.yyObjectGUIDs = objectGUIDs;
		function loadrec(out:Element, view:YyView, path:String) {
			for (el in view.children) {
				var res = resources[el];
				if (res == null) continue;
				var val = res.Value;
				var name:String, rel:String;
				var type = val.resourceType;
				if (type == "GMFolder") {
					var vdir:YyView = views[res.Key];
					if (out == null) {
						loadrec(out, vdir, null);
						continue;
					}
					name = vdir.folderName;
					if (path == "") switch (name) {
						case "objects", "scripts", "extensions": {
							name = name.charAt(0).toUpperCase() + name.substring(1);
						};
						default: {
							loadrec(null, vdir, null);
							continue;
						};
					}
					rel = path + name + "/";
					var dir = TreeView.makeDir(name, rel);
					loadrec(dir.treeItems, vdir, rel);
					out.appendChild(dir);
				} else {
					name = rxName.replace(val.resourcePath, "$1");
					rel = path + name;
					var full = Path.join([dir, val.resourcePath]);
					switch (type) {
						case "GMSprite", "GMTileSet", "GMSound", "GMPath",
						"GMScript", "GMShader", "GMFont", "GMTimeline",
						"GMObject", "GMRoom": {
							var atype = type.substring(2).toLowerCase();
							GmlAPI.gmlKind.set(name, "asset." + atype);
							comp.push(new AceAutoCompleteItem(name, atype));
						};
					}
					if (out == null) continue;
					switch (type) {
						case "GMScript": {
							full = Path.withoutExtension(full) + ".gml";
							GmlSeeker.run(full, name);
						};
						case "GMObject": {
							objectNames.set(res.Key, name);
							objectGUIDs.set(name, res.Key);
							GmlSeeker.run(full, null);
						};
						default: continue;
					}
					out.appendChild(TreeView.makeItem(name, rel, full));
				}
			}
		}
		TreeView.saveOpen();
		TreeView.clear();
		loadrec(TreeView.element, rootView, "");
		TreeView.restoreOpen();
		//
		return null;
	}
}