// SecGuardian OpenCode 插件
// deploy.sh 原样 cp 到 ~/.config/opencode/plugins/ 或 .opencode/plugins/
// extension 路径由插件自身位置推导: plugins/../extensions/secguardian

import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, join } from 'node:path'

const __dirname = dirname(fileURLToPath(import.meta.url))
const extDir = resolve(__dirname, '..', 'extensions', 'secguardian')

const CMDS = [
  { name: 'secguard',  file: 'secguard.md',  desc: '安全加固项排查 — 67 个检测器覆盖 7 大安全分类' },
  { name: 'secaudit',  file: 'secaudit.md',  desc: '★ 旗舰产品：AI 深度安全审计 — 17 项专业安全分析' },
  { name: 'secreview', file: 'secreview.md', desc: '安全编码规范检视 — 5 语言反模式检测矩阵 + 最佳实践合规审查' },
]

export const SecGuardianPlugin = async () => {
  return {
    config: (cfg) => {
      cfg.command = cfg.command || {}

      for (const cmd of CMDS) {
        const cmdPath = join(extDir, 'commands', cmd.file)
        if (!existsSync(cmdPath)) {
          console.error(`[SecGuardian] command file not found: ${cmdPath}`)
          continue
        }
        cfg.command[cmd.name] = {
          template: readFileSync(cmdPath, 'utf-8'),
          description: cmd.desc,
        }
      }

      // Register skills directory so AI can discover secaudit/secguard/secreview skills
      const skillsDir = join(extDir, 'skills')
      cfg.skills = cfg.skills || { paths: [] }
      if (!cfg.skills.paths.includes(skillsDir)) {
        cfg.skills.paths.push(skillsDir)
      }

      // Register knowledge directories so AI can discover rules
      const knowledgeDir = join(extDir, 'knowledge')
      cfg.knowledge = cfg.knowledge || { paths: [] }
      if (!cfg.knowledge.paths.includes(knowledgeDir)) {
        cfg.knowledge.paths.push(knowledgeDir)
      }
    }
  }
}
