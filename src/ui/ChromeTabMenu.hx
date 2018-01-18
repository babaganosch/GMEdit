package ui;
import electron.Menu;
import js.html.Element;
import ui.ChromeTabs;
using tools.HtmlTools;

/**
 * ...
 * @author YellowAfterlife
 */
class ChromeTabMenu {
	public static var target:ChromeTab;
	public static var menu:Menu;
	static var showInDirectoryItem:MenuItem;
	static var showInTreeItem:MenuItem;
	public static function show(el:ChromeTab) {
		target = el;
		var hasFile = el.gmlFile.path != null;
		showInDirectoryItem.enabled = hasFile;
		showInTreeItem.enabled = hasFile;
		menu.popupAsync();
	}
	public static function init() {
		menu = new Menu();
		menu.append(new MenuItem({ label: "Close", click: function() {
			target.querySelector(".chrome-tab-close").click();
		} }));
		menu.append(new MenuItem({ label: "Close Others", click: function() {
			for (tab in target.parentElement.querySelectorEls(".chrome-tab")) {
				if (tab != target) tab.querySelector(".chrome-tab-close").click();
			}
		} }));
		menu.append(new MenuItem({ label: "Close All", click: function() {
			for (tab in target.parentElement.querySelectorEls(".chrome-tab")) {
				tab.querySelector(".chrome-tab-close").click();
			}
		} }));
		menu.append(new MenuItem({ type: MenuItemType.Sep }));
		//
		menu.append(showInDirectoryItem = new MenuItem({
			label: "Show in directory",
			click: function() {
				electron.Shell.showItemInFolder(target.gmlFile.path);
			}
		}));
		menu.append(showInTreeItem = new MenuItem({
			label: "Show in tree",
			click: function() {
				var tree = TreeView.element;
				var path = target.gmlFile.path;
				var item = tree.querySelector('.item[${TreeView.attrPath}="$path"]');
				if (item == null) return;
				var par = item;
				do {
					if (par.classList.contains("dir")) par.classList.add("open");
					par = par.parentElement;
				} while (par != null);
				untyped item.scrollIntoViewIfNeeded();
			}
		}));
	}
}
