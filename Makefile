.PHONY: update-libraries build run clean

update-libraries:
	@mkdir -p build
	@cd build && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=1 ../src
	@cp build/compile_commands.json .vscode/

build:
	@docker build . -t mostsignificant/simplehttpserver

run:
	@docker run --rm mostsignificant/simplehttpserver

clean:
	@rm -rf build
	@docker rmi mostsignificant/simplehttpserver 2>/dev/null || true

