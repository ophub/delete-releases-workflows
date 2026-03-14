# Function Description / 功能说明

This Action can delete Releases and Workflow run logs of a specified repository.

此 Action 可删除指定仓库的 Releases 和 Workflow 运行记录。

## Instructions / 使用说明

You can use this Action by referencing it in a `.github/workflows/*.yml` workflow script, as shown in [delete.yml](https://github.com/ophub/amlogic-s9xxx-armbian/blob/main/.github/workflows/delete-older-releases-workflows.yml).

在 `.github/workflows/*.yml` 工作流脚本中引用此 Action 即可使用，示例参见 [delete.yml](https://github.com/ophub/amlogic-s9xxx-armbian/blob/main/.github/workflows/delete-older-releases-workflows.yml)。

```yaml
- name: Delete releases and workflows runs
  uses: ophub/delete-releases-workflows@main
  with:
    delete_releases: true
    releases_keep_latest: 5
    delete_workflows: true
    workflows_keep_day: 10
    gh_token: ${{ secrets.GITHUB_TOKEN }}
```

## Configuration / 配置说明

The following options can be configured in the delete.yml file:

可在 delete.yml 文件中配置以下选项：

| Key / 选项               | Required   | Description / 说明                       |
| ----------------------- | ---------- | ---------------------------------------- |
| delete_releases         | `Required`<br />`必选项` | Whether to delete Releases (options: `true`/`false`). Default: `false`.<br />是否删除 Releases（选项：`true`/`false`），默认为 `false`。 |
| prerelease_option       | Optional<br />可选项 | Filter by pre-release status (options: `all`/`true`/`false`). `all` includes all types; `true`/`false` deletes only Releases matching the specified pre-release flag. Default: `all`.<br />按预发布状态筛选（选项：`all`/`true`/`false`）。`all` 表示所有类型；`true`/`false` 仅删除与该预发布标记匹配的 Releases。默认为 `all`。 |
| releases_keep_latest    | Optional<br />可选项 | Number of latest Releases to keep (integer, e.g. `5`). Set to `0` to delete all. Default: `90`.<br />保留最新 Releases 的数量（整数，如 `5`）。设置为 `0` 表示全部删除，默认保留 `90` 个。 |
| releases_keep_keyword   | Optional<br />可选项   | Keywords in Release tags to preserve. Separate multiple keywords with `/` (e.g. `book/tool`). Default: none.<br />需要保留的 Release 标签关键字，多个关键字以 `/` 分隔（例如：`book/tool`）。默认值：无。 |
| delete_tags             | Optional<br />可选项   | Whether to delete tags associated with Releases (options: `true`/`false`). Default: `false`.<br />是否删除与 Releases 关联的标签（选项：`true`/`false`），默认为 `false`。 |
| delete_workflows        | `Required`<br />`必选项` | Whether to delete Workflow run logs (options: `true`/`false`). Default: `false`.<br />是否删除 Workflow 运行记录（选项：`true`/`false`），默认为 `false`。 |
| workflows_keep_day      | Optional<br />可选项 | Number of days of Workflow run logs to retain (integer, e.g. `30`). Set to `0` to delete all. Default: `90` days.<br />保留最近几天的 Workflow 运行记录（整数，如 `30`）。设置为 `0` 表示全部删除，默认为 `90` 天。 |
| workflows_keep_keyword  | Optional<br />可选项   | Keywords in Workflow run log names to preserve. Separate multiple keywords with `/` (e.g. `book/tool`). Default: none.<br />需要保留的 Workflow 运行记录名称关键字，多个关键字以 `/` 分隔（例如：`book/tool`）。默认值：无。 |
| out_log                 | Optional<br />可选项   | Whether to output detailed JSON logs (options: `true`/`false`). Default: `false`.<br />是否输出详细的 JSON 日志（选项：`true`/`false`），默认为 `false`。 |
| repo                    | Optional<br />可选项   | Target repository in `<owner>/<repo>` format. Default: the current repository.<br />目标仓库，格式为 `<owner>/<repo>`。默认为当前仓库。 |
| gh_token                | `Required`<br />`必选项` | [GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication) used to authenticate the delete operations.<br />用于验证删除操作的 [GITHUB_TOKEN](https://docs.github.com/zh/actions/security-guides/automatic-token-authentication#about-the-github_token-secret)。 |

- Each run can delete up to 1000 Releases and 1000 Workflow run logs. If more records exist, run the action multiple times.
- 每次运行最多可删除 1000 个 Releases 和 1000 条 Workflow 运行记录。如果记录数超出上限，需多次执行该操作。

## Links / 链接

- [GitHub Docs](https://docs.github.com/en/rest/releases/releases?list-releases)
- [unifreq/openwrt_packit](https://github.com/unifreq/openwrt_packit)
- [amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian)
- [amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt)
- [flippy-openwrt-actions](https://github.com/ophub/flippy-openwrt-actions)

## License / 许可协议

delete-releases-workflows © OPHUB is licensed under [GPL-2.0](https://github.com/ophub/delete-releases-workflows/blob/main/LICENSE).
