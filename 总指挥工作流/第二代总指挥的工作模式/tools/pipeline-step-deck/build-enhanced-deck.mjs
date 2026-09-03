import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const toolRoot = path.dirname(fileURLToPath(import.meta.url));
const runtimePath = path.join(toolRoot, "PIPELINE_STEP_DECK_ENHANCEMENTS.js");
const [inputArgument, outputArgument] = process.argv.slice(2);

if (!inputArgument) {
  console.error("用法：node build-enhanced-deck.mjs <输入HTML> [输出HTML]");
  process.exit(2);
}

const inputPath = path.resolve(process.cwd(), inputArgument);
const parsedInput = path.parse(inputPath);
const outputPath = outputArgument
  ? path.resolve(process.cwd(), outputArgument)
  : path.join(parsedInput.dir, parsedInput.name + "-enhanced" + parsedInput.ext);

const [html, runtime] = await Promise.all([
  readFile(inputPath, "utf8"),
  readFile(runtimePath, "utf8")
]);

if (!/<\/body>/i.test(html)) throw new Error("输入文件缺少 </body>，无法安全注入增强器");
if (!/id=["']evidenceStage["']/i.test(html)) throw new Error("输入文件不是受支持的链路演示模板");
if (/data-pipeline-step-deck-enhancements=/i.test(html)) throw new Error("输入文件已经包含增强器，请从未增强的模板重新生成");

const safeRuntime = runtime.replace(/<\/script/gi, "<\\/script");
const injection = [
  "  <script data-pipeline-step-deck-enhancements=\"1.0.0\">",
  safeRuntime,
  "  </script>"
].join("\n");
const output = html.replace(/<\/body>/i, injection + "\n</body>");

await mkdir(path.dirname(outputPath), { recursive: true });
await writeFile(outputPath, output, "utf8");
console.log(JSON.stringify({
  input: inputPath,
  output: outputPath,
  runtimeVersion: "1.0.0",
  bytes: Buffer.byteLength(output)
}, null, 2));
