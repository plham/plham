package plham.util;
import x10.util.ArrayList;
import x10.util.HashMap;
import x10.util.HashSet;
import x10.util.List;
import x10.util.Map;
import x10.util.Set;
import x10.util.Stack;
import cassia.util.JSON;

public class JSONUtils {

	private static class Graph {
		private val NodeID:HashMap[String, Long];
		private val NodeName:Rail[String];
		private val V:Long; // the number of vertices
		private val g:Rail[ArrayList[Long]];  // the graph represented by adjacency list
		private val rg:Rail[ArrayList[Long]]; // the reverse graph of g
		public def this(originalGraph:Map[String, Set[String]]) {
			V = originalGraph.size();
			g = new Rail[ArrayList[Long]](V);
			rg = new Rail[ArrayList[Long]](V);
			for (v in 0 .. (V - 1)) {
				g(v) = new ArrayList[Long]();
				rg(v) = new ArrayList[Long]();
			}
			NodeID = new HashMap[String, Long]();
			NodeName = new Rail[String](V);
			var curID:Long = 0;
			for (key in originalGraph.keySet()) {
				if (NodeID.containsKey(key)) continue;
				NodeName(curID) = key;
				NodeID(key) = curID++;
			}
			assert curID == this.V;
			for (entry in originalGraph.entries()) {
				val dst = NodeID(entry.getKey());
				for (v in entry.getValue()) {
					val src = NodeID(v);
					Console.OUT.println("# src: " + src + " dst: " + dst + " V: " + V);
					addEdge(src, dst);
				}
			}
		}
		private def addEdge(val src:Long, val dst:Long) {
			g(src).add(dst);
			rg(dst).add(src);
		}
		public def sort():Rail[String] {
			val order = calcTopologicalOrder();
			val ans = new Rail[String](V);
			for (i in 0 .. (V - 1)) {
				ans( order(i) ) = NodeName(i);
			}
			return ans;
		}
		private def calcTopologicalOrder():Rail[Long] {
			val used = new Rail[Boolean](V, false);
			val vs = new ArrayList[Long]();
			for (v in 0 .. (V - 1)) {
				if (used(v)) continue;
				forward(v, vs, used);
			}
			for (i in used.range()) { used(i) = false; }
			var k:Long = 0;
			val order = new Rail[Long](V);
			for (i in order.range()) { order(i) = -1; }
			vs.reverse();
			for (v in vs) {
				if (used(v)) continue;
				back(v, k++, order, vs, used);
			}
			return order;
		}
		private def forward(v:Long, vs:ArrayList[Long], used:Rail[Boolean]):void {
			used(v) = true;
			for (u in g(v)) {
				if (used(u)) continue;
				forward(u, vs, used);
			}
			vs.add(v);
		}
		private def back(v:Long, k:Long, order:Rail[Long], vs:ArrayList[Long], used:Rail[Boolean]):void {
			used(v) = true;
			order(v) = k;
			for (u in rg(v)) {
				if (used(u)) continue;
				back(u, k, order, vs, used);
			}
		}
	}

	public static def getDependencyGraph(root:JSON.Value, list:JSON.Value, keywords:List[String]):Map[String, Set[String]] {
		val graph = new HashMap[String, Set[String]]();
		val stack = new Stack[String]();
		for (i in 0 .. (list.size() - 1)) {
			val name = list(i).toString();
			stack.push(name);
		}
		while (stack.size() > 0) {
			val name = stack.pop();
			Console.OUT.println("#GRAPH " + name + " checking");
			if (! graph.containsKey(name)) {
				graph(name) = new HashSet[String]();
			}
			for (keyword in keywords) {
				if (root(name).has(keyword)) {
					val children = root(name)(keyword);
					for (i in 0 .. (children.size() - 1)) {
						val child = children(i).toString();
						stack.push(child);
						graph(name).add(child);
						Console.OUT.println("#GRAPH " + name + " --> " + child + " created");
					}
				}
			}
		}
		return graph;
	}

	public static def getDependencySortedList(root:JSON.Value, list:JSON.Value, keywords:List[String]):List[String] {
		val graph = new Graph(getDependencyGraph(root, list, keywords));
		val rail = graph.sort();
		val retval = new ArrayList[String]();
		retval.addAll(rail);
		Console.OUT.println("#GRAPH-SORTED " + retval);
		return retval;
	}

	public static def getDependencyGraph(root:JSON.Value, list:JSON.Value, keyword:String):Map[String,Set[String]] {
		val graph = new HashMap[String,Set[String]]();
		val stack = new Stack[String]();
		for (i in 0..(list.size() - 1)) {
			val name = list(i).toString();
			stack.push(name);
		}
		var t:Long = 0;
		while (stack.size() > 0) {
			val name = stack.pop();
			Console.OUT.println("#GRAPH " + name + " checking");
			if (!graph.containsKey(name)) {
				graph(name) = new HashSet[String]();
			}
			if (root(name).has(keyword)) {
				val children = root(name)(keyword);
				for (j in 0..(children.size() - 1)) {
					val child = children(j).toString();
					stack.push(child);
					graph(name).add(child);
					Console.OUT.println("#GRAPH " + name + " --> " + child + " created");
				}
			}
			t++;
		}
		return graph;
	}

	public static def getDependencySortedList(root:JSON.Value, list:JSON.Value, keyword:String):List[String] {
		val graph = getDependencyGraph(root, list, keyword);
		val nodes = new ArrayList[String]();
		nodes.addAll(graph.keySet()); // X10 doesn't allow in-loop state changes.

		// TODO: Efficient algorithm.
		val sorted = new ArrayList[String]();
		while (graph.size() > 0) {
			val numNodes = graph.size();
			for (name in nodes) {
				if (graph(name).size() == 0) {
					sorted.add(name);
					for (parent in graph.keySet()) {
						if (graph(parent).remove(name)) {
							Console.OUT.println("#GRAPH " + parent + " --> " + name + " removed");
						}
					}
					graph.remove(name);
					nodes.remove(name);
					Console.OUT.println("#GRAPH " + name + " removed");
				}
			}
			if (numNodes == graph.size()) {
				throw new Exception("Circular dependency of '" + keyword + "' detected");
			}
		}
		Console.OUT.println("#GRAPH-SORTED " + sorted);
		return sorted;
	}
}
