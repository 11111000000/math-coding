import { useQuery } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import { rpcSchemas } from "../shared/schemas";
import type { ConsoleTheme } from "../shared/theme";
import { useHost } from "./host/context";
import { HostModalContent } from "./host/sheet";
import { useT } from "./i18n";
import { Badge, Body, Button, Empty, Mono, Note } from "./parts";
import { previewChild, previewIsOpen, previewParent, previewTarget } from "./preview-target";

const MAX_LINES = 400;

/**
 * The read-only preview of one entry of the workspace.
 *
 * The human opens the subject of a claim without leaving the panel. The
 * preview shows what the project contains; it never shows a state and never
 * changes anything.
 */
export function FilePreview({ theme, compact, workspaceId, path, onClose }: {
  theme: ConsoleTheme;
  compact: boolean;
  workspaceId: string;
  path: string | null;
  onClose: () => void;
}) {
  const { Modal, useRpc, useToast, copyText } = useHost();
  const t = useT();
  const fetchFile = useRpc(rpcSchemas.file);
  const toast = useToast();
  const [navigated, setNavigated] = useState<string | null>(null);
  useEffect(() => { setNavigated(null); }, [path]);
  const current = previewTarget(path, navigated);
  const query = useQuery({
    queryKey: ["mathcoding-file", workspaceId, current],
    queryFn: () => fetchFile({ workspaceId, path: current ?? "", maxBytes: 131_072 }),
    enabled: current !== null,
    retry: false,
  });
  const open = (next: string) => setNavigated(next);
  const copyPath = async () => {
    if (!current) return;
    try {
      await copyText(current);
      toast.show(t("toast.path_copied"));
    } catch {
      toast.error(t("toast.path_not_copied"));
    }
  };
  const parent = previewParent(current);
  return (
    <Modal title={current ?? t("file.title")} open={previewIsOpen(path)} onOpenChange={(openState) => { if (!openState) { setNavigated(null); onClose(); } }}>
      <HostModalContent>
        <View style={{ gap: 10 }}>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center" }}>
            {parent !== null && <Button theme={theme} compact label={t("file.up")} icon="CornerLeftUp" onPress={() => open(parent)} />}
            <Button theme={theme} compact label={t("file.copy_path")} icon="Clipboard" onPress={() => void copyPath()} />
            <Button theme={theme} compact label={t("common.close")} icon="X" onPress={() => { setNavigated(null); onClose(); }} />
          </View>
          <Mono theme={theme}>{current ?? ""}</Mono>
          {query.isPending ? (
            <Empty theme={theme} title={t("file.reading")} icon="FileText" />
          ) : query.isError ? (
            <Note theme={theme} tone="bad">{t("file.read_error", { error: String(query.error) })}</Note>
          ) : query.data?.kind === "directory" ? (
            <View style={{ gap: 6 }}>
              <Body theme={theme} muted>{t("file.directory_entry", { count: query.data.entries.length })}</Body>
              {query.data.entries.map((entry) => (
                <Pressable
                  key={entry.name}
                  accessibilityRole="button"
                  accessibilityLabel={t("file.open_entry", { name: entry.name })}
                  onPress={() => open(previewChild(current, entry.name))}
                  style={{ padding: 8, borderRadius: 7, backgroundColor: theme.colors.surface2, flexDirection: "row", gap: 8, alignItems: "center" }}
                >
                  <Badge theme={theme} label={entry.kind} icon={entry.kind === "directory" ? "Folder" : "FileText"} />
                  <Text style={{ color: theme.colors.foreground, fontSize: 12, fontFamily: "monospace" }}>{entry.name}</Text>
                </Pressable>
              ))}
              {query.data.entries.length === 0 && <Empty theme={theme} title={t("file.empty_directory")} icon="FolderOpen" />}
              {query.data.truncated && <Body theme={theme} muted>{t("file.listing_bounded")}</Body>}
            </View>
          ) : query.data?.kind === "file" ? (
            <View style={{ gap: 6 }}>
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
                <Badge theme={theme} label={t("file.bytes", { bytes: query.data.bytes })} icon="HardDrive" />
                {query.data.binary && <Badge theme={theme} label={t("file.binary_badge")} tone="warn" icon="FileWarning" />}
                {query.data.truncated && <Badge theme={theme} label={t("file.truncated_badge")} tone="warn" icon="Scissors" />}
              </View>
              {query.data.binary ? (
                <Body theme={theme} muted>{t("file.binary_note")}</Body>
              ) : (
                <ScrollView style={{ maxHeight: compact ? 260 : 420 }} nestedScrollEnabled>
                  <View style={{ backgroundColor: theme.colors.surface2, borderRadius: 8, padding: 10 }}>
                    <Text selectable style={{ color: theme.colors.foreground, fontSize: 11, lineHeight: 16, fontFamily: "monospace" }}>
                      {query.data.content.split("\n").slice(0, MAX_LINES).join("\n")}
                    </Text>
                  </View>
                </ScrollView>
              )}
              {query.data.content.split("\n").length > MAX_LINES && (
                <Body theme={theme} muted>{t("file.showing_lines", { shown: MAX_LINES, total: query.data.content.split("\n").length })}</Body>
              )}
              {query.data.truncated && <Body theme={theme} muted>{t("file.larger_than_limit")}</Body>}
            </View>
          ) : null}
        </View>
      </HostModalContent>
    </Modal>
  );
}
