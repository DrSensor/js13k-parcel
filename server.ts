import { readFile } from "fs/promises";

(async () => {
  console.log(await readFile("./LICENSE"));
})();
