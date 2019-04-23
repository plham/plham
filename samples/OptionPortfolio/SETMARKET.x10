
public class SETMARKET {

	public static def main(args:Rail[String]) {
		var v:String = args(0);		
		var n:Long = Int.parseInt(args(1));
		assert n>0: "WriteSETMARKET1Error";

		if(v.equals("SETMARKETCLUSTERS1")){
			var out:String = setMarket1(n);
			Console.OUT.print(out);
		}else if(v.equals("SETMARKETCLUSTERS2")){
			var out:String = setMarket2(n);
			Console.OUT.print(out);
		}else if(v.equals("SETUNDERLYIGNMARKET1")){
			var out:String = setUnderMarket1(n);
			Console.OUT.print(out);
		}else if(v.equals("SETUNDERLYIGNMARKET2")){
			var out:String = setUnderMarket2(n);
			Console.OUT.print(out);
		}else if(v.equals("SETNORMALLOCALAGENT1")){
			var out:String = setNormalLocalAgent1(n);
			Console.OUT.print(out);
		}else if(v.equals("SETNORMALLOCALAGENT2")){
			var out:String = setNormalLocalAgent2(n);
			Console.OUT.print(out);
		}else if(v.equals("SETBASELLOCALAGENT1")){
			var out:String = setBaselLocalAgent1(n);
			Console.OUT.print(out);
		}else if(v.equals("SETBASELLOCALAGENT2")){
			var out:String = setBaselLocalAgent2(n);
			Console.OUT.print(out);
		}else if(v.equals("SETOPTIONAGENT1")){
			var out:String = setOptionAgent1(n);
			Console.OUT.print(out);
		}else if(v.equals("SETOPTIONAGENT2")){
			var out:String = setOptionAgent2(n);
			Console.OUT.print(out);
		}
	}

	public static def setMarket1(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s +"\"OptionMarketCluster"+ i +"\"";
			if(i!=n){
				s = s +",";
			}
		}
		return s;
	}

	public static def setMarket2(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s+ "\"OptionMarketCluster" +i +"\"" + ": { \"extends" + "\"" + " : \"OptionMarketCluster" + "\", \"markets"+"\": [\"market-" + i +  "\" ] }";
			if(i!=n){
				s = s +"," + "  ";
			}
		}
		return s;
	}

	public static def setUnderMarket1(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s +"\"market-"+ i +"\"";
			if(i!=n){
				s = s +",";
			}
		}
		return s;
	}

	public static def setUnderMarket2(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s+ "\"market-"+i+"\": { \"extends\": \"class-Market\" }";
			if(i!=n){
				s = s +"," + "  ";
			}
		}
		return s;
	}

	public static def setNormalLocalAgent1(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s +"\"normalLocal"+ i +"\"";
			if(i!=n){
				s = s +",";
			}
		}
		return s;
	}

	public static def setNormalLocalAgent2(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s+ "\"normalLocal" +i +"\"" + ": { \"extends" + "\"" + " : \"normalLocalAgent" + "\", \"accessibleMarkets"+"\": [\"market-" + i +  "\" ] }";
			if(i!=n){
				s = s +"," + "  ";
			}
		}
		return s;
	}

	public static def setBaselLocalAgent1(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s +"\"baselLocal"+ i +"\"";
			if(i!=n){
				s = s +",";
			}
		}
		return s;
	}

	public static def setBaselLocalAgent2(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s+ "\"baselLocal" +i +"\"" + ": { \"extends" + "\"" + " : \"baselLocalAgent" + "\", \"accessibleMarkets"+"\": [\"market-" + i +  "\" ] }";
			if(i!=n){
				s = s +"," + "  ";
			}
		}
		return s;
	}

	public static def setOptionAgent1(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s +"\"FCNOptionAgent"+ i +"\"";
			if(i!=n){
				s = s +",";
			}
		}
		return s;
	}

	public static def setOptionAgent2(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s+ "\"FCNOptionAgent" +i +"\"" + ": { \"extends" + "\"" + " : \"FCNOptionAgent" + "\", \"markets"+"\": [\"market-" + i + "\", \"OptionMarketCluster" + i + "\" ] }";
			if(i!=n){
				s = s +"," + "  ";
			}
		}
		return s;
	}
}
