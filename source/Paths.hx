package;

import animateatlas.AtlasFrameMaker;
import flixel.math.FlxPoint;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import openfl.geom.Rectangle;
import flixel.math.FlxRect;
import haxe.xml.Access;
import openfl.system.System;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;
import flixel.FlxSprite;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
#if android
import android.os.Environment;
#end
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import haxe.Json;
import flash.media.Sound;

using StringTools;

class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	#if android
	public static var androidPath:String = Environment.getExternalStorageDirectory() + "/.OSEngine/";
	#end

	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> = [
		'characters', 'custom_events', 'custom_notetypes', 'data', 'songs',
		'music', 'sounds', 'shaders', 'videos', 'images', 'stages',
		'objects', 'weeks', 'fonts', 'scripts', 'achievements'
	];
	#end

	public static var dumpExclusions:Array<String> = [
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/shared/music/breakfast.$SOUND_EXT',
		'assets/shared/music/tea-time.$SOUND_EXT',
	];

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static function clearUnusedMemory() {
		for (key in currentTrackedAssets.keys()) {
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key)) {
				var obj = currentTrackedAssets.get(key);
				@:privateAccess
				if (obj != null) {
					openfl.Assets.cache.removeBitmapData(key);
					FlxG.bitmap._cache.remove(key);
					obj.destroy();
					currentTrackedAssets.remove(key);
				}
			}
		}
		System.gc();
	}

	public static var localTrackedAssets:Array<String> = [];
	public static function clearStoredMemory(?cleanUnused:Bool = false) {
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys()) {
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedAssets.exists(key)) {
				openfl.Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		for (key in currentTrackedSounds.keys()) {
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && key != null) {
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		localTrackedAssets = [];
		openfl.Assets.cache.clear("songs");
	}

	static public var currentModDirectory:String = '';
	static public var currentLevel:String;

	static public function setCurrentLevel(name:String) {
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, type:AssetType, ?library:Null<String> = null) {
		if (library != null) return getLibraryPath(file, library);

		if (currentLevel != null) {
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(file, currentLevel);
				if (fileExists(levelPath, type)) return levelPath;
			}
			levelPath = getLibraryPathForce(file, "shared");
			if (fileExists(levelPath, type)) return levelPath;
		}
		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload") {
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String) {
		return '$library:assets/$library/$file';
	}

	inline public static function getPreloadPath(file:String = '') {
		#if android
		return androidPath + 'assets/$file';
		#else
		return 'assets/$file';
		#end
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String) {
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String) return getPath('data/$key.txt', TEXT, library);
	inline static public function xml(key:String, ?library:String) return getPath('data/$key.xml', TEXT, library);
	inline static public function json(key:String, ?library:String) return getPath('data/$key.json', TEXT, library);
	inline static public function shaderFragment(key:String, ?library:String) return getPath('shaders/$key.frag', TEXT, library);
	inline static public function shaderVertex(key:String, ?library:String) return getPath('shaders/$key.vert', TEXT, library);
	inline static public function lua(key:String, ?library:String) return getPath('$key.lua', TEXT, library);

	static public function video(key:String) {
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) return file;
		#end
		return getPreloadPath('videos/$key.$VIDEO_EXT');
	}

	static public function sound(key:String, ?library:String):Sound return returnSound('sounds', key, library);
	inline static public function music(key:String, ?library:String):Sound return returnSound('music', key, library);

	inline static public function voices(song:String):Any {
		var songKey:String = '${formatToSongPath(song)}/Voices';
		return returnSound('songs', songKey);
	}

	inline static public function inst(song:String):Any {
		var songKey:String = '${formatToSongPath(song)}/Inst';
		return returnSound('songs', songKey);
	}

	inline static public function image(key:String, ?library:String):FlxGraphic return returnGraphic(key, library);

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String {
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key))) return File.getContent(modFolders(key));
		#end
		if (FileSystem.exists(getPreloadPath(key))) return File.getContent(getPreloadPath(key));
		#end
		return Assets.getText(getPath(key, TEXT));
	}

	inline static public function font(key:String) {
		#if MODS_ALLOWED
		var file:String = modsFont(key);
		if(FileSystem.exists(file)) return file;
		#end
		return getPreloadPath('fonts/$key');
	}

	inline static public function fileExists(key:String, type:AssetType) {
		#if MODS_ALLOWED
		if(FileSystem.exists(mods(currentModDirectory + '/' + key)) || FileSystem.exists(mods(key))) return true;
		#end
		if(FileSystem.exists(getPreloadPath(key)) || OpenFlAssets.exists(getPath(key, type))) return true;
		return false;
	}

	inline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames {
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var xmlPath:String = modsXml(key);
		if(FileSystem.exists(xmlPath)) {
			return FlxAtlasFrames.fromSparrow(imageLoaded, File.getContent(xmlPath));
		}
		#end
		return FlxAtlasFrames.fromSparrow(image(key, library), getTextFromFile('images/$key.xml'));
	}

	inline static public function formatToSongPath(path:String) return path.toLowerCase().replace(' ', '-');

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static function returnGraphic(key:String, ?library:String) {
		#if MODS_ALLOWED
		var modKey:String = modsImages(key);
		if(FileSystem.exists(modKey)) {
			if(!currentTrackedAssets.exists(modKey)) {
				var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(modKey), false, modKey);
				newGraphic.persist = true;
				currentTrackedAssets.set(modKey, newGraphic);
			}
			localTrackedAssets.push(modKey);
			return currentTrackedAssets.get(modKey);
		}
		#end

		var path = getPreloadPath('images/$key.png');
		if (FileSystem.exists(path)) {
			if(!currentTrackedAssets.exists(path)) {
				var newGraphic:FlxGraphic = FlxG.bitmap.add(BitmapData.fromFile(path), false, path);
				newGraphic.persist = true;
				currentTrackedAssets.set(path, newGraphic);
			}
			localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}
		return null;
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(path:String, key:String, ?library:String) {
		#if MODS_ALLOWED
		var file:String = modsSounds(path, key);
		if(FileSystem.exists(file)) {
			if(!currentTrackedSounds.exists(file)) currentTrackedSounds.set(file, Sound.fromFile(file));
			localTrackedAssets.push(file);
			return currentTrackedSounds.get(file);
		}
		#end

		var gottenPath:String = getPreloadPath('$path/$key.$SOUND_EXT');
		if(FileSystem.exists(gottenPath)) {
			if(!currentTrackedSounds.exists(gottenPath)) currentTrackedSounds.set(gottenPath, Sound.fromFile(gottenPath));
			localTrackedAssets.push(gottenPath);
			return currentTrackedSounds.get(gottenPath);
		}
		return null;
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '') return #if android androidPath + 'mods/' + key #else 'mods/' + key #end;
	inline static public function modsFont(key:String) return modFolders('fonts/' + key);
	inline static public function modsJson(key:String) return modFolders('data/' + key + '.json');
	inline static public function modsVideo(key:String) return modFolders('videos/' + key + '.' + VIDEO_EXT);
	inline static public function modsSounds(path:String, key:String) return modFolders(path + '/' + key + '.' + SOUND_EXT);
	inline static public function modsImages(key:String) return modFolders('images/' + key + '.png');
	inline static public function modsXml(key:String) return modFolders('images/' + key + '.xml');
	inline static public function modsTxt(key:String) return modFolders('images/' + key + '.txt');

	static public function modFolders(key:String) {
		if(currentModDirectory != null && currentModDirectory.length > 0) {
			var fileToCheck:String = mods(currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck)) return fileToCheck;
		}
		for(mod in getGlobalMods()){
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck)) return fileToCheck;
		}
		return mods(key);
	}

	public static var globalMods:Array<String> = [];
	static public function getGlobalMods() return globalMods;

	static public function pushGlobalMods() {
		globalMods = [];
		var path:String = #if android androidPath + 'modsList.txt' #else 'modsList.txt' #end;
		if(FileSystem.exists(path)) {
			var list:Array<String> = File.getContent(path).trim().split('\n');
			for (i in list) {
				var dat = i.split("|");
				if (dat[1] == "1") {
					var folder = dat[0];
					var packPath = mods(folder + '/pack.json');
					if(FileSystem.exists(packPath)) {
						try {
							var stuff:Dynamic = Json.parse(File.getContent(packPath));
							if(Reflect.getProperty(stuff, "runsGlobally")) globalMods.push(dat[0]);
						} catch(e:Dynamic) trace(e);
					}
				}
			}
		}
		return globalMods;
	}
	#end
}
