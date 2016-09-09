package cassia.util;
import x10.io.File;
import x10.util.ArrayList;
import x10.util.HashMap;
import x10.util.List;
import x10.util.Map;
import x10.util.StringBuilder;

/**
 * A JSON parser written in X10.
 * 
 * <p>Restrictions:<ul>
 * <li> No type recognition for literals (stored as string)
 * <li> No escape sequence handling
 * </ul>
 *
 * <p>Use <code>JSON.parse()</code> to obtain a JSON object from a string or file.
 * 
 * <p>See {@link JSON.Value} to know how to access to the JSON data.
 * 
 * <p>Syntax:
 * <p><pre>
 *     json := object
 *     name := ( string | literal )
 *     value := ( object | array | string | literal )
 *     object := "{" [ name ":" value [ "," name ":" value ]&ast; ] "}"
 *     array := "[" [ value [ "," value ]&ast; ] "]"
 *     string := QUOTE [ CHARACTER ]&ast; QUOTE
 *     literal := ( LETTERS | DIGITS | "_" | "." | "+" | "-" )+
 * </pre>
 */
public class JSON {

	/**
	 * <code>JSON.parse(String)</code> returns <code>JSON.Value</code>.
	 * 
	 * <p>To access the content, use the <i>apply</i> operators:
	 * <p><pre>
	 *     val json = JSON.parse(...);
	 *     val x = json("x");
	 *     val y = json("y", "default");     // default
	 *     val z = json(["z1", "z2", "z3"]); // first one
	 * </pre>
	 * <p>If the key is a number, it is interpreted as a JSON Array (or X10 List) type.
	 * If the key is a string, it is interpreted as a JSON Object (or X10 Map) type.
	 * See the definition below for details.
	 */
	public static class Value {
		
		var value:Any; // String, List, or Map (never Boolean, Long, Double, etc)
		var p:Reader;
		var i:Int;

		public def this(value:Any, p:Reader, i:Int) {
			this.value = value;
			this.p = p;
			this.i = i;
		}

		public def this(value:Any) {
			this(value, null, 0n);
		}

		/**
		 * Get the value associated with the key if exists.
		 * The key can be of any type.
		 * The key is first casted in <code>toString()</code> and then
		 * treated as <code>Long</code> if <code>isList()</code> but as <code>String</code> if <code>isMap()</code>.
		 * <pre>
		 *     JSON: {"one": {"two": {"three": 3}}}
		 *     X10 : json("one")("two")("three").toLong()    // gets 3
		 * </pre>
		 * @param s  a key
		 * @return the value
		 */
		public def get[T](s:T):Value {
			if (!this.has(s)) {
				throw new JSONException("No key: " + s);
			}
			if (this.isList()) {
				val i = Long.parse(s.toString());
				return this.asList()(i);
			}
			if (this.isMap()) {
				return this.asMap().get(s.toString());
			}
			throw new JSONException("No key: " + s);
		}

		/**
		 * Get the final value associated with all the keys in the list.
		 * <pre>
		 *     JSON: {"one": {"two": {"three": 3}}}
		 *     X10 : json(["one", "two", "three"]).toLong()    // gets 3
		 * </pre>
		 * @param s  a key list
		 * @return the value
		 */
		public def get[T](s:Rail[T]):Value {
			var v:Value = this;
			for (i in 0..(s.size - 1)) {
				if (v.has(s(i))) {
					v = v.get(s(i));
				} else {
					throw new JSONException("No key: " + s);
				}
			}
			return v;
		}

		/**
		 * Get the value associated with the key if exists;
		 * Otherwise return <code>JSON.parse(orElse)</code>.
		 * <pre>
		 *     JSON: {"one": {"two": {"three": 3}}}
		 *     X10 : json("one")("two")("threat", "13").toLong()    // gets 13
		 * </pre>
		 * @param s  a key
		 * @param orElse  a JSON text used if <code>s</code> not found
		 * @return the value
		 */
		public def getOrElse[T](s:T, orElse:String):Value {
			if (this.has(s)) {
				return this.get(s);
			}
			return parse(orElse);
		}

		public def set(v:Any) {
			this.value = v;
		}

		public def put[T](s:T, v:Value) {
			if (this.isList()) {
				val i = Long.parse(s.toString());
				return this.asList()(i) = v;
			}
			if (this.isMap()) {
				return this.asMap().put(s.toString(), v);
			}
			throw new JSONException("Cannot assign to " + s + ": " + v);
		}

		public def put[T](s:T, v:Any) {
			return this.put(s, new Value(v.toString()));
		}

		/**
		 * Test if it has the key <code>s</code>.
		 * @param s  a key
		 * @return
		 */
		public def has[T](s:T):Boolean {
			if (this.isList()) {
				val i = Long.parse(s.toString());
				return 0 <= i && i < this.asList().size();
			}
			if (this.isMap()) {
				return this.asMap().containsKey(s.toString());
			}
			return false;
		}

		/**
		 * Get the value associated with the key first matched if any such exists.
		 * <pre>
		 *     JSON: {"one": 1, "TWO": 2, "THREE": 3}
		 *     X10 : json(["ONE", "TWO", "THREE"]).toLong()    // gets 2
		 * </pre>
		 * @param s  a key list
		 * @return the value
		 */
		public def any[T](s:Rail[T]):Value {
			for (i in 0..(s.size - 1)) {
				if (this.has(s(i))) {
					return this.get(s(i));
				}
			}
			throw new JSONException("No key: " + s);
		}

		/**
		 * Get the size of this JSON Array or JSON Object (otherwise return 0).
		 * @return
		 */
		public def size():Long {
			if (this.isList()) {
				return this.asList().size();
			}
			if (this.isMap()) {
				return this.asMap().size();
			}
			return 0;
		}

		/**
		 * Get the value associated with the key if exists.
		 * The key can be of any type.
		 * The key is first casted in <code>toString()</code> and then
		 * treated as <code>Long</code> if <code>isList()</code> but as <code>String</code> if <code>isMap()</code>.
		 * <pre>
		 *     JSON: {"one": {"two": {"three": 3}}}
		 *     X10 : json("one")("two")("three").toLong()    // gets 3
		 * </pre>
		 * @param key  a key
		 * @return the value
		 */
		public operator this[T](key:T):Value {
			return this.get(key);
		}

		public operator this[T](key:T) = (v:Value) {
			return this.put(key, v);
		}

		public operator this[T](key:T) = (v:Any) {
			return this.put(key, v);
		}

		/**
		 * Get the value associated with the key if exists;
		 * Otherwise returns <code>JSON.parse(orElse)</code>.
		 * <pre>
		 *     JSON: {"one": {"two": {"three": 3}}}
		 *     X10 : json("one")("two")("threat", "13").toLong()    // gets 13
		 * </pre>
		 * @param key  a key
		 * @param orElse  a JSON text used if <code>s</code> not found
		 * @return the value
		 */
		public operator this[T](key:T, orElse:String):Value {
			return this.getOrElse(key, orElse);
		}

		/**
		 * Get the value associated with the key first matched if any such exists.
		 * <pre>
		 *     JSON: {"one": 1, "TWO": 2, "THREE": 3}
		 *     X10 : json(["ONE", "TWO", "THREE"]).toLong()    // gets 2
		 * </pre>
		 * @param keys  a key list
		 * @return the value
		 */
		public operator this[T](keys:Rail[T]):Value {
			return this.any(keys);
		}

		public def isNull():Boolean {
			return this.value == null;
		}

		public def isMap():Boolean {
			return this.value instanceof Map[String,Value];
		}

		public def asMap():Map[String,Value] {
			return this.value as Map[String,Value];
		}

		public def isList():Boolean {
			return this.value instanceof List[Value];
		}

		public def asList():List[Value] {
			return this.value as List[Value];
		}

		/**
		 * Perform a String-vs-String equality test.
		 * Any argument is casted to String and then compared.
		 * This is to avoid the common pitfall:
		 * Without overriding <code>equals()</code>, the following
		 * <pre>
		 *     json("x").equals("x")
		 * </pre>
		 * results in the unintended <code>JSON.Value</code>-vs-<code>String</code> test,
		 * returning always false.
		 * @param that
		 * @return
		 */
		public def equals(that:Any):Boolean {
			return this.toString().equals(that.toString());
		}

		/**
		 * Get an error message with the JSON text around.
		 * @return
		 */
		protected def getExInfo():String {
			if (this.p == null) {
				return this.value.toString();
			}
			return this.p.toString(this.i);
		}

		/**
		 * Cast this <code>JSON.Value</code> to String.
		 * Use <code>JSON.dump()</code> instead.
		 * @return
		 */
		public def toString():String {
			try {
				return this.value as String;
			} catch (Exception) {
				throw new JSONException("Cannot cast to String: " + this.getExInfo());
			}
		}

		public def toBoolean():Boolean {
			try {
				return Boolean.parse(this.value as String);
			} catch (Exception) {
				throw new JSONException("Cannot cast to Boolean: " + this.getExInfo());
			}
		}

		public def toInt():Int {
			try {
				return Int.parse(this.value as String);
			} catch (Exception) {
				throw new JSONException("Cannot cast to Int: " + this.getExInfo());
			}
		}

		public def toLong():Long {
			try {
				return Long.parse(this.value as String);
			} catch (Exception) {
				throw new JSONException("Cannot cast to Long: " + this.getExInfo());
			}
		}

		public def toDouble():Double {
			try {
				return Double.parse(this.value as String);
			} catch (Exception) {
				throw new JSONException("Cannot cast to Double: " + this.getExInfo());
			}
		}

		public def clone():Value {
			var value:Any = this.value;
			if (this.isList()) {
				val a = this.asList();
				val h = new ArrayList[Value]();
				for (item in a) { h.add(item.clone()); }
				value = h;
			}
			if (this.isMap()) {
				val a = this.asMap();
				val h = new HashMap[String,Value]();
				for (key in a.keySet()) { h(key) = a(key).clone(); }
				value = h;
			}
			return new Value(value, this.p, this.i);
		}
	}

	static class Reader {
		
		public var text:String;
		public var i:Int;

		public def this(text:String) {
			this.text = text;
			this.i = 0n;
		}

		public def get():Char {
			return this.text(this.i);
		}

		public def next() {
			this.i++;
		}

		public def toString(i:Int):String {
			return this.text.substring(Math.max(0n, i - 20n), Math.min(i + 20n, this.text.length()));
		}
	}

	static class JSONException extends Exception {

		public def this(s:String) {
			super(s);
		}
		
		public def this(p:Reader) {
			super(p.toString(p.i));
		}
	}

	public static def isJSONLetter(p:Reader) {
		val c = p.get();
		return (c.isLetter() || c.isDigit() || c == '_' || c == '.' || c == '+' || c == '-');
	}

	public static def isJSONQuote(p:Reader) {
		val c = p.get();
		return (c == '"' || c == '\''); //"
	}

	public static def skipSpaces(p:Reader) {
		while (p.get().isWhitespace()) {
			p.next();
		}
	}

	public static def parseLiteral(p:Reader):String {
		val b = p.i;

		while (isJSONLetter(p)) {
			p.next();
			if (p.i >= p.text.length()) {
				break;
			}
		}
		if (b == p.i) {
			throw new JSONException(p);
		}
		return p.text.substring(b, p.i);
	}

	public static def parseString(p:Reader):String {
		val quote = p.get();
		if (isJSONQuote(p)) {
			p.next();
		} else {
			throw new JSONException(p);
		}

		val b = p.i;

		while (p.i < p.text.length()) {
			if (p.get() == quote) {
				p.next();
				break;
			} else {
				p.next();
			}
		}
		if (p.i >= p.text.length()) {
			throw new JSONException(p);
		}
		return p.text.substring(b, p.i - 1n);
	}

	public static def parseValue(p:Reader):Any {
		if (p.get() == '{') {
			return parseObject(p);
		} else if (p.get() == '[') {
			return parseArray(p);
		} else if (isJSONQuote(p)) {
			return parseString(p);
		} else {
			return parseLiteral(p);
		}
	}

	public static def parseName(p:Reader):String {
		if (isJSONQuote(p)) {
			return parseString(p);
		} else {
			return parseLiteral(p);
		}
	}

	public static def parseObject(p:Reader):Map[String,Value] {
		val a = new HashMap[String,Value]();

		if (p.get() == '{') {
			p.next();
		} else {
			throw new JSONException(p);
		}

		skipSpaces(p);
		if (p.get() == '}') {
			p.next();
			return a;
		}

		while (true) {
			skipSpaces(p);
			val s = parseName(p);

			skipSpaces(p);
			if (p.get() == ':') {
				p.next();
			} else {
				throw new JSONException(p);
			}

			skipSpaces(p);
			val i = p.i;
			val v = parseValue(p);

			a.put(s, new Value(v, p, i));

			skipSpaces(p);
			if (p.get() == ',') {
				p.next();
			} else {
				break;
			}
		}

		skipSpaces(p);
		if (p.get() == '}') {
			p.next();
		} else {
			throw new JSONException(p);
		}
		return a;
	}

	public static def parseArray(p:Reader):List[Value] {
		val a = new ArrayList[Value]();

		if (p.get() == '[') {
			p.next();
		} else {
			throw new JSONException(p);
		}

		skipSpaces(p);
		if (p.get() == ']') {
			p.next();
			return a;
		}

		while (true) {
			skipSpaces(p);
			val i = p.i;
			val v = parseValue(p);

			a.add(new Value(v, p, i));

			skipSpaces(p);
			if (p.get() == ',') {
				p.next();
			} else {
				break;
			}
		}

		skipSpaces(p);
		if (p.get() == ']') {
			p.next();
		} else {
			throw new JSONException(p);
		}
		return a;
	}

	/**
	 * Parse the string and compose a JSON object.
	 */
	public static def parse(text:String) {
		val p = new Reader(text);
		skipSpaces(p);
		val i = p.i;
		val v = parseValue(p); // This allows any JSON values.
		return new Value(v, p, i);
	}

	/**
	 * Parse the file and compose a JSON object.
	 */
	public static def parse(file:File) {
		val s = new StringBuilder();
		for (line in file.lines()) {
			s.add(line);
			s.add(" ");
		}
		return parse(s.toString());
	}

	private static def _extendChain(root:JSON.Value, focus:JSON.Value, out:HashMap[String,Value]) {
		if (!focus.isMap()) {
			return;
		}
		if (focus.has("extends")) {
			val child = focus("extends");
			_extendChain(root, root(child), out);
		}
		val dict = focus.asMap();
		for (key in dict.keySet()) {
			out(key) = dict(key);
		}
	}

	/**
	 * Handle the "extends" keyword for JSON objects at level/depth = 1
	 * (not recursive).
	 * Modify the JSON.Value object given and return itself.
	 */
	public static def extend(root:JSON.Value):JSON.Value {
		if (!root.isMap()) {
			return root;
		}
		for (key in root.asMap().keySet()) {
			if (!root(key).isMap()) {
				continue;
			}
			if (root(key).has("extends")) {
				val out = new HashMap[String,Value]();
				_extendChain(root, root(key), out);
				root(key).value = out;
			}
		}
		return root;
	}

	/**
	 * Stringify the JSON object.
	 */
	public static def dump(root:JSON.Value):String {
		val s = new StringBuilder();
		if (root.isMap()) {
			s.add("{");
			val d = root.asMap();
			val n = d.size();
			var i:Long = 0;
			for (key in d.keySet()) {
				s.add("\"");
				s.add(key.toString());
				s.add("\"");
				s.add(":");
				s.add(dump(d(key)));
				if (++i < n) {
					s.add(",");
				}
			}
			s.add("}");
		} else if (root.isList()) {
			s.add("[");
			val a = root.asList();
			val n = a.size();
			var i:Long = 0;
			for (elem in a) {
				s.add(dump(elem));
				if (++i < n) {
					s.add(",");
				}
			}
			s.add("]");
		} else {
			s.add("\"");
			s.add(root.value.toString());
			s.add("\"");
		}
		return s.toString();
	}

	public static def main(args:Rail[String]) {
		var json:JSON.Value;
		if (args.size > 0) {
			json = JSON.parse(new File(args(0)));
		} else {
			json = JSON.parse("{'first': 1, 'second': 2, 'third': [1,2,'c'], '4th': {'one': { 'more': b.c.c } }, nullobj: { }, 1  : [],  spaces  : 'a a a'    ,   123   : 123  }");
		}

		Console.OUT.println(JSON.dump(json));

		JSON.extend(json);

		Console.OUT.println(JSON.dump(json));

		val z = JSON.parse("{}");
		Console.OUT.println(JSON.dump(z("a", "{'a':1}")));

		val x = new JSON.Value("x");
		val y = new JSON.Value("2.0");
		Console.OUT.println("x.toString().equals('x'): " + x.toString().equals("x"));
		Console.OUT.println("x.equals('x'): " + x.equals("x"));
		Console.OUT.println("x.equals('w'): " + x.equals("w"));
		Console.OUT.println("y.equals(2.0): " + y.equals(2.0));
		//Console.OUT.println("y.equals(2): " + y.equals(2));
		Console.OUT.println("y.equals(1.1): " + y.equals(1.1));

		Console.OUT.println(json.size());
		Console.OUT.println(json("first").size());
		Console.OUT.println(json("first").toDouble());
		Console.OUT.println(json("third").size());
		Console.OUT.println(json("first"));
		Console.OUT.println(json("first").toString());
		
		//json.put("5th", JSON.parse("123"));
		val clon = json.clone();
		clon("5th") = 123;
		clon("first") = "10000000000";
		clon("4th")("one") = "ichi";
		Console.OUT.println("5th: " + clon("5th"));
		Console.OUT.println(JSON.dump(json));
		Console.OUT.println(JSON.dump(clon));

		Console.OUT.println("JSON.Value as key: " + json(new JSON.Value("first")));

		Console.OUT.println("third");
		Console.OUT.println(json("third")(1).toLong());
		Console.OUT.println(json("third")("1").toLong());
		Console.OUT.println(json("third")("1").toDouble());
		Console.OUT.println(json("third")("2").toString());
		Console.OUT.println("end third");
		Console.OUT.println(json("4th")("one")("more").toString());
		Console.OUT.println(json.get(["third", 2]).toString());
		Console.OUT.println(json.get(["third", "2"]).toString());
		Console.OUT.println(json.get(["4th", "one", "more"]).toString());
		Console.OUT.println(json.get(["4th", "onetwo", "more"]));
		Console.OUT.println(json("4th")("onetwo")("more"));
		Console.OUT.println(json("4th").any(["three", "two"]).get("more"));
		Console.OUT.println(json("4th").any(["three", "two"])("more").toString());

		Console.OUT.println("END");
	}
}
