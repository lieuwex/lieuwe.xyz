const fs = require('fs');
const express = require('express');
const mkdirp = require('mkdirp');

const router = express.Router();
const HTTPHOST = 'lieuwe.xyz';
const FILES_DIRNAME = 'files';

mkdirp.sync(FILES_DIRNAME);

let startid;
try {
	startid = +fs.readFileSync(`${FILES_DIRNAME}/startid`);
	if(isNaN(startid)||startid<0){
		throw 0;
	}
} catch(_){
	startid = 42424242;
}
const genidcode = (() => {
	let i = startid;
	return () => {
		const code = `0000000${(i*47%4294967291).toString(36)}`.slice(-7);
		//(x -> nx) : F_p -> F_p with p prime and 0<n<x is a bijection
		i++;
		fs.writeFileSync(`${FILES_DIRNAME}/startid`,i.toString());
		let res = '';
		for (let j = 0; j < 7; j++) {
			res += code[2*j % 7];
		} //same goes here
		return res;
	}
})();

setInterval(() => {
	const dirlist = fs.readdirSync(FILES_DIRNAME);
	const nowtime = new Date().getTime();
	for (const file of dirlist) {
		if (file.slice(-6) === '-fname' || file === 'startid') {
			continue;
		}
		const path = `${FILES_DIRNAME}/${file}`;
		try {
			const stats = fs.statSync(path);
			if(!stats.isFile()){
				continue;
			}
			if(nowtime-stats.mtime.getTime()>24*3600*1000){ //24 hour storage
				fs.unlinkSync(path);
				fs.unlinkSync(path+'-fname');
			}
		} catch(e){
			console.log(`[cleanup] Couldn't process '${path}': ${e.message}`);
		}
	}
},3600*1000); //every hour

router.post('/gooi/:fname', (req, res) => {
	const fname = req.params.fname.replace(/[\0-\x1f\x7f-\xff\/"\\]/g,'');
	if (fname.length === 0) {
		res.writeHead(400);
		res.end('Invalid filename given');
		return;
	}
	const id = genidcode();

	let fd;
	try {
		fd = fs.openSync(`${FILES_DIRNAME}/${id}`,'w');
	} catch (e) {
		console.log(e);
		res.writeHead(500);
		res.end('Could not open file to write to\n');
		return;
	}
	const stream = fs.createWriteStream(null,{ fd: fd });
	req.pipe(stream);
	req.on('end',function(){
		fs.writeFileSync(`${FILES_DIRNAME}/${id}-fname`,fname);
		res.writeHead(200);
		res.end(`http://${HTTPHOST}/vang/${id}\n`);
	});
	req.on('error',function(e){
		console.log(e);
		res.writeHead(500);
		res.end('Error while writing file\n');
		try {
			fs.closeSync(fd);
		} catch(e){}
	});
});

router.get('/vang/:id', (req, res) => {
	const id = req.params.id.replace(/[^0-9a-z]/g,'').substr(0,10);
	if (
		!fs.existsSync(`${FILES_DIRNAME}/${id}`) ||
		!fs.existsSync(`${FILES_DIRNAME}/${id}-fname`)
	) {
		res.writeHead(404);
		res.end('404 not found');
		return;
	}
	const fname = fs.readFileSync(`${FILES_DIRNAME}/${id}-fname`).toString();
	const fnamequo = `"${fname}"`;

	let filedesc = null;
	let stats = null;
	try {
		const datafname = `${FILES_DIRNAME}/${id}`;
		filedesc = fs.openSync(datafname,'r');
		stats = fs.statSync(datafname);
	} catch(e){
		console.log(e);
		res.writeHead(500);
		res.end('Could not open file\n');
		return;
	}
	res.writeHead(200,{
		'Content-Type':'routerlication/octet-stream',
		'Content-Length':stats.size.toString(),
		'Content-Disposition':`attachment; filename = ${fnamequo}`,
	});
	fs.createReadStream(null,{ fd:filedesc }).pipe(res);
	res.on('error',function(e){
		console.log(e);
	});
});

router.post('/houvast/:id', (req, res) => {
	const id = req.params.id.replace(/[^0-9a-z]/g,'').substr(0,10);
	if(!fs.existsSync(`${FILES_DIRNAME}/${id}`)||!fs.existsSync(`${FILES_DIRNAME}/${id}-fname`)){
		res.writeHead(404);
		res.end('404 not found');
		return;
	}

	try {
		const fd = fs.openSync(`${FILES_DIRNAME}/${id}`,'a');
		const now = new Date();
		fs.futimesSync(fd,now,now);
		fs.closeSync(fd);
	} catch(e){
		console.log(e);
		res.writeHead(500);
		res.end('Could not open file\n');
		return;
	}
	res.writeHead(200);
	res.end('200 ok');
});

module.exports = router;
