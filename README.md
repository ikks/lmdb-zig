# lmdb-zig
**[Zig](https://ziglang.org) bindings to [Lightning Memory-Mapped Database (LMDB)](http://www.lmdb.tech/doc/) (key-value storage)**
<br><br>

**LMDB features**
- basically, mmap-ed B+tree
- the best read performance over all database/storages
- really fast writes (the fastest for short (100 B) and long (8+ KB) keys, ~25-95% speed of the top LSM-based approaches for medium (~4 KB) keys)
- ACID-compliant, transactional (totally-safe)
- save and restore from filesystem backups
<br>

**lmdb-zig features**
- works in 2024
- built and tested on the latest stable versions of Zig (0.13) and lmdb (0.9.31)
- all functions covered except unnecessary ones
- deep testing (see [Features & tests](#features-tests))
- easy intall



## Install
- (if no `build.zig` in proj root)
  ```
  zig init
  ```
- ```
  zig fetch --save https://github.com/john-g4lt/lmdb-zig
  ```
- add to `build.zig`
  
  after `lib`, but before `b.intallArtifact(lib)`:

  ```zig
  const lmdb = b.dependency("lmdb-zig", .{ .target = target, .optimize = optimize });
  lib.linkLibrary(lmdb);
  ```

  after `exe`, but before `b.intallArtifact(exe)`:
  
  ```zig
  exe.root_module.addImport("lmdb-zig", lmdb.module("lmdb-zig-mod"));
  exe.linkLibrary(lmdb);
  ```
- import
  ```zig
  pub const lmdb = @import("lmdb-zig");
  ```



## Example
[example.zig](https://github.com/john-g4lt/lmdb-zig/blob/main/example.zig)
```zig
pub const std = @import("std");
pub const lmdb = @import("lmdb-zig");

pub fn main() !void {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = try tmp.dir.realpath("./", &buf);

    const env = try lmdb.Env.init(path, .{});
    defer env.deinit();

    const iters = 2_000;
    const word_len = 5;
    const words_cnt = 3;
    const key_len = (word_len + 1) * words_cnt - 1;
    const keys = comptime blk: {
        @setEvalBranchQuota(1.3 * iters * words_cnt * word_len);
        var keys = std.mem.zeroes([iters][key_len]u8);
        for (0..iters) |i| for (0..words_cnt) |wi| {
            for (0..word_len) |j|
                keys[i][(word_len + 1) * wi + j] = 97 + (i + j) % 25;
            if (wi != words_cnt - 1)
                keys[i][(word_len + 1) * wi + word_len] = '-';
        };
        break :blk keys;
    };

    var t = try std.time.Timer.start();
    t.reset();
    for (keys) |k| {
        const tx = try env.begin(.{});
        errdefer tx.deinit();
        const db = try tx.open(null, .{});
        defer db.close(env);
        try tx.put(db, &k, &k, .{});
        try tx.commit();
    }
    const ns_write = t.read();
    std.debug.print("write {d} keys {d:.2} ms {d:.2} ops/s\n", .{ iters, ns_write / 1_000_000, (iters * 1_000_000_000) / ns_write });
    t.reset();
    const get_iters_mul = 1000;
    for (0..get_iters_mul) |_| for (keys) |k| {
        const tx = try env.begin(.{});
        errdefer tx.deinit();
        const db = try tx.open(null, .{});
        defer db.close(env);
        const x = try tx.get(db, &k);
        if (std.mem.eql(u8, x, &k) == false)
            @panic(x);
        try tx.commit();
    };
    const ns_read = t.read();
    std.debug.print("read {d}*{d} keys {d:.2} ms {d:.2} ops/ms\n", .{ iters, get_iters_mul, ns_read / 1_000_000, (get_iters_mul * iters * 1_000_000) / ns_write });
}
```
<br>

my output (with `-Doptimize=ReleaseFast` and 20 yo laptop):
```
write 2000 keys 1744 ms 1146 ops/s
read 2000*1000 keys 482 ms 1146 ops/ms
```
so ~1.15 write/s and ~1.15 Mil reads/s



## API coverage & tests
- `Env: .init() .deinit() .stats() .info() and flags`
- `Env.save_to(): backup and restore`
- `Env.sync(): manually flush system buffers`
- `Tx: .get() .put() .reserve() .delete() .commit() several entries with .overwrite_key = true / false`
- `Tx: .reserve() .write() and attempt to .reserve() again with .overwrite_key = false`
- `Tx.get_or_put() twice`
- `Tx: use multiple named databases in a single transaction`
- `Tx: nest transaction inside transaction`
- `Tx: custom key comparator`
- `Tx: custom key comparator`
- `Cursor: move around a database and add / delete some entries`
- `Cursor: interact with variable-sized items in a database with duplicate keys`



## Extra credits
partially based on [lithdew's and iacore's lmdb-zig](https://github.com/iacore/lmdb-zig), 
but fully reworked to compile with Zig 0.13



## Devlog & TODO
- [x] reimplement [lithdew's and iacore's lmdb-zig](https://github.com/iacore/lmdb-zig) repo 
  to run on Zig 0.13 & run tests & publish
- [ ] fix `.put_batch()` segfault & test
- [ ] rework api to be less messy in real use
- [ ] indie benchmark with RocksDB and BerkleyDB

