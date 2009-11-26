/*
	The MIT License

	Copyright (c) 2009 Guilherme Almeida and Mauro de Tarso

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
	
	http://code.google.com/p/textanim/
	http://flupie.net
*/       

package flupie.textanim
{	
	import flash.display.Sprite;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.setTimeout;
	import flash.events.Event;

	/**
	 * <code>TextAnim</code> is a abstract and extensible Class to create text animations.
	 *
	 */
	public class TextAnim extends Sprite
	{
		public static const BREAK_IN_LETTERS:String = Breaker.BREAK_IN_LETTERS;
		public static const BREAK_IN_WORDS:String = Breaker.BREAK_IN_WORDS;
		public static const BREAK_IN_LINES:String = Breaker.BREAK_IN_LINES;

		public static const ANIM_TO_RIGHT:String = ActionFlow.FIRST_TO_LAST;
		public static const ANIM_TO_LEFT:String = ActionFlow.LAST_TO_FIRST;
		public static const ANIM_TO_CENTER:String = ActionFlow.EDGES_TO_CENTER;
		public static const ANIM_TO_EDGES:String = ActionFlow.CENTER_TO_EDGES;
		public static const ANIM_RANDOM:String = ActionFlow.RANDOM;  
		
		/**
		* The original TextField instance.
		* <p>That's can be whatever TextField instance, but you need to make sure to embed font</p>
		*/
		public var source:TextField;
		
		/**
		* effects is a list <code>Array</code> of function. Will be called for all blocks
		* according to the interval specified.
		*/
		public var effects:*;
		
		/**
		* interval for dispatch blocks, description...
		* 
		* @default 100
		*/
		public var interval:Number = 100;
		
		/**
		* Time is to limit the time for dispatching blocks.
		* <p>If it has a value different 0 that's overwrites the interval.</p>
		*       
		* @default 0
		*/
		public var time:Number = 0;
		
		/**
		* Callback function called when the TextAnim start
		*/
		public var onStart:Function;
		
		/**
		* Callback function called during the blocks are dispatch
		*/
		public var onProgress:Function;
		
		/**
		* Callback function called it's done, all the blocks was dispatch 
		*/
		public var onComplete:Function;
		
		/**
		* animMode description...
		*       
		* @default ActionFlow.FIRST_TO_LAST
		* @see breakMode
		*/
		public var animMode:String = ActionFlow.FIRST_TO_LAST;
		
		/**
		* blocks is a public array contains all blocks
		*/
		public var blocks:Array;
		
		private var _breakMode:String = Breaker.BREAK_IN_LETTERS;
		private var _text:String;
		private var _blocksVisibility:Boolean = true;
		private var flow:ActionFlow;
		private var evStart:Event;
		private var evProgress:Event;
		private var evComplete:Event;
		
		/**
		* The constructor recive your TextField instance
		*
		* @param source The TextField instance
		* @param autoReplace To make <code>swapChildren</code> of original TextField to TextAnim instance 
		* 
		* @see stop
		*/
		public function TextAnim(source:TextField, autoReplace:Boolean = true)
		{
			super();

			this.source = source;
			
			evStart = new Event(TextAnimEvent.START);
			evProgress = new Event(TextAnimEvent.PROGRESS);
			evComplete = new Event(TextAnimEvent.COMPLETE);
			
			flow = new ActionFlow();
			flow.onStart = startHandler; 
			flow.onProgress = progressHandler; 
			flow.onComplete = completeHandler; 

			blocks = [];
			text = source.htmlText;

			x = source.x;
			y = source.y;

			if (autoReplace) {
				if (source.parent != null) {
					source.parent.addChild(this);
					source.parent.swapChildren(this, source);
					source.parent.removeChild(source);
				}
			}
		}

		/**
		* To change text, that's will restart all.
		*	
		* @param value 
		*/
		public function set text(value:String):void
		{
			source.htmlText = value;
			createBlocks();
		}

		public function get text():String { return source.text; }

		/**
		* breakMode is a setter to specify how the TextAnim will breack the text block.
		*	
		* @param value 
		*/
		public function set breakMode(value:String):void
		{
			_breakMode = value;
			createBlocks();
		}

		public function get breakMode():String { return _breakMode; }

		/**
		* start is the go ahead function.
		*
		* @param delay Time to wait before start.
		* 
		* @see stop
		*/
		public function start(delay:Number = 0):void
		{
			if (delay == 0) {
				flowSettings();
				flow.start();
			} else {
				setTimeout(function():void {
					flowSettings();
					flow.start();
				}, delay);
			}
		}

		/**
		* stop to dispatch blocks
		* 
		* @see dispose
		*/
		public function stop():void
		{
			flow.stop();
		}

		/**
		* dispose method clear all internal reference and stop progress
		*/
		public function dispose():void
		{
			if (flow == null) return;

			stop();

			removeBlocks();
			blocks = null;

			flow.clear();
			flow = null;
			
			evStart = null;
			evProgress = null;
			evComplete = null;

			if (parent != null) {
				if (parent.contains(this)) parent.removeChild(this);
			}

			source = null;
		}

		/**
		* setBlocksVisibility description...
		*/
		public function setBlocksVisibility(visibility:Boolean):void
		{
			_blocksVisibility = visibility;
			applyToAllBlocks(function(block:TextAnimBlock):void {
				block.visible = visibility;
			})
		}

		/**
		* setBlocksVisibility description...
		*/
		public function applyEffect(blockIndex:int):void
		{
			var effectList:Array = effects is Array ? effects : [effects];
			var bl:TextAnimBlock = blocks[blockIndex];

			if(bl != null){
				bl.visible = true;
				if (effects != null) {
					for (var k:int = 0; k<effectList.length; k++){
						var eff:Function = effectList[k];
						eff(bl);
					}
				}
			}
		}

		/**
		* applyToAllBlocks description...
		*/
		public function applyToAllBlocks(act:Function):void
		{
			for (var i:int = 0; i < blocks.length; i++) {
				act(blocks[i]);
			}
		}

		private function createBlocks():void
		{
			if (blocks.length > 0) removeBlocks();

			flow.clear();
			blocks = Breaker.separeBlocks(this, _breakMode);

			for (var i:int = 0; i < blocks.length; i++) {
				var block:TextAnimBlock = blocks[i];
				addChild(block);

				blockSettings(block);
			}
		}

		private function removeBlocks():void
		{
			flow.clear();

			applyToAllBlocks(function(block:TextAnimBlock):void {
				if (contains(block)) removeChild(block);
				block.dispose();
				block = null
			});
			blocks = [];
		}

		private function blockSettings(block:TextAnimBlock):void
		{
			var bounds:Rectangle = source.getCharBoundaries(block.index);
			if (bounds == null) bounds = new Rectangle();
			var fmt:TextFormat = source.getTextFormat(block.index, block.index+1);

			var modX:Number = (fmt.indent as Number) + (fmt.leftMargin as Number);

			block.posX = block.x = bounds.x - 2 - modX;
			block.posY = block.y = bounds.y - 2;
			block.textField.setTextFormat(fmt);

			block.visible = _blocksVisibility;
		}

		private function flowSettings():void
		{
			var eff:Function;
			var effectList:Array = effects is Array ? effects : [effects];

			flow.clear();
			flow.way = animMode;
			if (time > 0) {
				flow.time = time;
			} else {
				flow.time = interval*blocks.length;
			}

			for (var i:int=0; i<blocks.length; i++) {
				flow.addFunction(function(id:Number):void{
					applyEffect(id);
				});
			}
		}
		
		private function completeHandler():void
		{
			if (onComplete != null) onComplete();
			dispatchEvent(evComplete); 
		}    
		
		private function progressHandler():void
		{        
			if (onProgress != null) onProgress();
			dispatchEvent(evProgress); 
		}
		
		private function startHandler():void
		{         
			if (onStart != null) onStart(); 
			dispatchEvent(evStart); 
		}

	}
}