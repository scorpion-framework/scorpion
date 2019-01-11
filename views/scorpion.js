const scorpion = {
	
	ajax: function(info){
		var request = new XMLHttpRequest();
		request.open(info.method, info.path);
		request.setRequestHeader('Content-Type', 'application/json');
		request.onreadystatechange = function(){
			if(request.readyState == 4) {
				if(request.status >= 200 && request.status < 300) {
					if(info.success) info.success(JSON.parse(request.responseText), request);
				} else {
					if(info.fail) info.fail(request);
				}
			}
		};
		request.send(JSON.stringify(info.data));
	},
	
	get: function(info){
		info.method = 'GET';
		scorpion.ajax(info);
	},
	
	post: function(info){
		info.method = 'POST';
		scorpion.ajax(info);
	},
	
	call: function(functionName, args, callback){
		scorpion.ajax({
			method: 'CALL',
			path: '/internal/function/' + functionName,
			data: args,
			success: callback
		});
	}
	
};
