function Test:main( args )
	for i=1,args:length() do
		System.print("Argument "..i.." = "..args:get(i))
	end
end