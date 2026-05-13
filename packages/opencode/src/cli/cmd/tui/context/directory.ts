import { createMemo } from "solid-js"
import { useProject } from "./project"
import { useSync } from "./sync"
import { Global } from "@opencode-ai/core/global"

function brandPath(value: string) {
  return value
    .replace(Global.Path.home, "~")
    .replaceAll("\\", "/")
    .replace(/\/packages\/opencode(?=\/|:|$)/g, "/packages/tryaksh")
}

export function useDirectory() {
  const project = useProject()
  const sync = useSync()
  return createMemo(() => {
    const directory = project.instance.path().directory || process.cwd()
    const result = brandPath(directory)
    if (sync.data.vcs?.branch) return result + ":" + sync.data.vcs.branch
    return result
  })
}
