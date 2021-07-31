package parsers.linter;
import ace.AceGmlTools;
import gml.GmlAPI;
import gml.GmlFuncDoc;
import gml.type.GmlType;
import gml.type.GmlTypeCanCastTo;
import gml.type.GmlTypeDef;
import gml.type.GmlTypeTools;
import parsers.linter.GmlLinterArrayAccess;
import tools.Aliases;
import parsers.linter.GmlLinter;
import tools.JsTools;
import tools.macros.GmlLinterMacros.*;

/**
 * ...
 * @author YellowAfterlife
 */
class GmlLinterArrayAccess {
	public static var outType:GmlType;
	public static var outKind:GmlLinterKind;
	public static function read(self:GmlLinter,
		nk:GmlLinterKind,
		newDepth:Int,
		currType:GmlType,
		currKind:GmlLinterKind
	):FoundError @:privateAccess {
		var isNull = nk == KNullSqb;
		
		// extract `Type` from `Type?` when doing `v?[indexer]`
		if ((isNull || self.optImplicitNullableCast) && currType.isNullable()) currType = currType.unwrapParam();
		
		var isArray = false;
		var isArray2d = false;
		var isLiteral = false;
		var arrayType1 = null;
		var arrayType2 = null;
		var checkColon = true;
		switch (self.peek()) {
			case KQMark: { // map[?k]
				self.skip();
				rc(self.readExpr(newDepth));
				currType = currType.resolve();
				var mapMeta = switch (currType) {
					case null: null;
					case TSpecifiedMap(mm): mm;
					default: null;
				}
				if (mapMeta != null) {
					switch (self.readExpr_currValue) {
						case VString(_, k):
							try {
								k = haxe.Json.parse(k);
								var mapField = mapMeta.fieldMap[k];
								currType = mapField != null ? mapField.type : mapMeta.defaultType;
							} catch (_) {
								currType = mapMeta.defaultType;
							}
						default:
							self.checkTypeCast(self.readExpr_currType, GmlTypeDef.string, "map key");
							currType = mapMeta.defaultType;
					}
				} else if (self.checkTypeCast(currType, GmlTypeDef.ds_map)) {
					self.checkTypeCast(self.readExpr_currType, currType.unwrapParam(0), "map key");
					currType = currType.unwrapParam(1);
				} else currType = null;
			};
			case KOr: { // list[|i]
				self.skip();
				
				rc(self.readExpr(newDepth));
				self.checkTypeCast(self.readExpr_currType, GmlTypeDef.number, "list index");
				
				currType = currType.resolve();
				if (self.checkTypeCast(currType, GmlTypeDef.ds_list)) {
					currType = currType.unwrapParam(0);
				} else currType = null;
			};
			case KDollar: { // struct[$k]
				self.skip();
				
				rc(self.readExpr(newDepth));
				self.checkTypeCast(self.readExpr_currType, GmlTypeDef.string, "struct key");
				
				if (true) { // todo: validate that object is struct-like
					currType = currType.unwrapParam(0);
				} else currType = null;
			};
			case KHash: { // grid[#x, y]
				self.skip();
				
				rc(self.readExpr(newDepth));
				self.checkTypeCast(self.readExpr_currType, GmlTypeDef.number, "grid X");
				
				rc(self.readCheckSkip(KComma, "a comma before second index"));
				rc(self.readExpr(newDepth));
				self.checkTypeCast(self.readExpr_currType, GmlTypeDef.number, "grid Y");
				
				currType = currType.resolve();
				if (self.checkTypeCast(currType, GmlTypeDef.ds_grid)) {
					currType = currType.unwrapParam(0);
				} else currType = null;
			};
			case KAtSign: { // array[@i] or array[@i, k]
				self.skip();
				isArray = true;
				checkColon = false;
				
				rc(self.readExpr(newDepth));
				arrayType1 = self.readExpr_currType;
				
				if (self.skipIf(self.peek() == KComma)) {
					isArray2d = true;
					rc(self.readExpr(newDepth));
					arrayType2 = self.readExpr_currType;
				}
			};
			default: { // array[i] or array[i, k]
				isArray = true;
				
				rc(self.readExpr(newDepth));
				arrayType1 = self.readExpr_currType;
				
				if (self.skipIf(self.peek() == KComma)) {
					isArray2d = true;
					rc(self.readExpr(newDepth));
					arrayType2 = self.readExpr_currType;
				}
				if (isNull && self.skipIf(self.peek() == KComma)) { // whoops, a?[b,c,d]
					self.readArgs(newDepth, true);
					isLiteral = true;
				}
			};
		}
		if (!isLiteral) rc(self.readCheckSkip(KSqbClose, "a closing `]` in array access"));
		if (isLiteral) {
			rc(self.readCheckSkip(KColon, "a colon in a ?: operator"));
			rc(self.readExpr(newDepth));
			currKind = KQMark;
		} else if (isNull && isArray && checkColon && self.peek() == KColon) { // whoops, a?[b]:c
			self.skip();
			rc(self.readExpr(newDepth));
			currKind = KQMark;
		} else {
			currKind = isNull ? KNullArray : KArray;
			if (isArray) {
				currType = currType.resolve();
				var ck = currType.getKind();
				switch (ck) {
					case KCustomKeyArray: {
						currType = currType.resolve();
						var indexType = currType.unwrapParam(0);
						if (arrayType1 != null) self.checkTypeCast(arrayType1, indexType);
						if (arrayType2 != null) self.checkTypeCast(arrayType2, indexType);
						currType = currType.unwrapParam(1);
					};
					case KTuple: {
						if (self.readExpr_currValue == null) {
							self.checkTypeCast(arrayType1, GmlTypeDef.number);
							if (isArray2d) self.addWarning("2d array access on a tuple");
							currType = null;
						} else switch (self.readExpr_currValue) {
							case VNumber(i, _):
								var p = currType.unwrapParams();
								if (i >= 0 && i < p.length) {
									currType = p[Std.int(i)];
								} else {
									currType = null;
								}
							default: currType = null;
						}
					};
					default: {
						if (arrayType1 != null) self.checkTypeCast(arrayType1, GmlTypeDef.number);
						if (arrayType2 != null) self.checkTypeCast(arrayType2, GmlTypeDef.number);
						currType = currType.resolve();
						if (self.checkTypeCast(currType, GmlTypeDef.anyArray)) {
							currType = currType.unwrapParam(0);
						} else currType = null;
					};
				}
			}
		}
		outType = currType;
		outKind = currKind;
		return false;
	}
}