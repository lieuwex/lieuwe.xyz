log = console.log
error = console.error
console.log = (str) -> log "\u001b[90m#{new Date().toISOString()}\u001b[39m #{str}"
console.error = (str) -> error "\u001b[31m#{new Date().toISOString()}\u001b[39m #{str}"
