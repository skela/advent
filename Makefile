
default:
	@zig build run

build:
	@zig build

release:
	@zig build --release=fast

run:
	@zig-out/bin/advent

