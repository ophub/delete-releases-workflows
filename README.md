# Function description / 功能说明

This Action can delete the Releases and Workflows runs of the specified repository.

这个 Actions 可以删除指定仓库的 Releases 和 Workflows 运行记录。

## Instructions / 使用说明

Introduce this Actions in the `.github/workflows/*.yml` workflows script to use, for example [delete.yml](https://github.com/ophub/amlogic-s9xxx-armbian/blob/main/.github/workflows/delete-older-releases-workflows.yml).

在 `.github/workflows/*.yml` 工作流脚本中引入此 Actions 即可使用，例如 [delete.yml](https://github.com/ophub/amlogic-s9xxx-armbian/blob/main/.github/workflows/delete-older-releases-workflows.yml)。

```yaml
- name: Delete releases and workflows runs
  uses: ophub/delete-releases-workflows@main
  with:
    del_releases: true
    releases_keep_latest: 5
    del_workflows: true
    workflows_keep_day: 10
    gh_token: ${{ secrets.GH_TOKEN }}
```

## Setting instructions / 设置说明

You can configure removal settings using the following keys in your delete.yml file:

您可以在 delete.yml 文件中使用以下选项配置删除设置：

| Key / 选项               | Required   | Description / 说明                       |
| ----------------------- | ---------- | ---------------------------------------- |
| delete_releases         | `Required`<br />`必选项` | Whether to delete releases records (options: `true`/`false`), default is `false`. <br />是否删除 releases 记录(选项：`true`/`false`)，默认为 `false`。 |
| releases_keep_latest    | Optional<br />可选项 | Set how many latest Releases versions to keep (`Integer`. eg: 5), Set to `0` to delete all, default is `90`. <br />设置保留几个最新的 Releases 版本（`整数`。如：5），设置为 `0` 表示全部删除，默认保留 `90` 个。 |
| releases_keep_keyword   | Optional<br />可选项   | The keywords of the releases that need to be reserved, Use `/` to separate multiple keywords (eg: `book/tool`), default is `""`. <br />需要保留的 Releases 的`关键字`，多个关键字使用 `/` 分割（例如：`book/tool`），默认值 `""`。 |
| delete_tags             | Optional<br />可选项   | Delete tags associated with releases (options: `true`/`false`), default is `false`. <br />删除与 Releases 关联的 tags (选项：`true`/`false`)，默认为 `false。` |
| delete_workflows        | `Required`<br />`必选项` | Whether to delete workflows records (options: `true`/`false`), default is `false`. <br />是否删除 workflows 记录(选项：`true`/`false`)，默认为 `false`。 |
| workflows_keep_day      | Optional<br />可选项 | Set the number of days to keep workflow runs (`Integer`. eg: 30), Set to `0` to delete all. default is `90` day. <br />设置保留几天以内的 workflows 记录（`整数`。如：30），设置为 `0` 表示全部删除。默认为 `90` 天。 |
| workflows_keep_keyword  | Optional<br />可选项   | The keywords of workflows runs that need to be reserved, Use `/` to separate multiple keywords (eg: `book/tool`), default is `""`. <br />需要保留的 workflows 运行记录的`关键字`，多个关键字使用 `/` 分割（例如：`book/tool`），默认值 `""`。 |
| out_log                 | Optional<br />可选项   | Whether to output a listing log for each step (options: `true`/`false`), default is `false`. <br />是否为每个步骤输出一个列表日志 (选项：`true`/`false`)，默认值 `false`。 |
| repo                    | Optional<br />可选项   | Set the `<owner>/<repo>` to perform the operation, the default is the `current repository`. <br />设置执行操作的 `<owner>/<repo>` ，默认为`当前仓库`。 |
| gh_token                | `Required`<br />`必选项` | Set the [GH_TOKEN](https://github.com/ophub/amlogic-s9xxx-armbian/tree/main/build-armbian/documents#2-set-the-privacy-variable-github_token) for performing delete operations. <br />设置执行删除操作的 [GH_TOKEN](https://github.com/ophub/amlogic-s9xxx-armbian/tree/main/build-armbian/documents#2-set-the-privacy-variable-github_token) 口令。 |

## Links / 链接

- [GitHub Docs](https://docs.github.com/en/rest/releases/releases?list-releases)
- [unifreq/openwrt_packit](https://github.com/unifreq/openwrt_packit)
- [amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian)
- [amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt)
- [flippy-openwrt-actions](https://github.com/ophub/flippy-openwrt-actions)

## License / 许可

The delete-releases-workflows © OPHUB is licensed under [GPL-2.0](https://github.com/ophub/delete-releases-workflows/blob/main/LICENSE)

