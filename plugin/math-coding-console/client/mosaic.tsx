import type { PluginTheme } from "@getpaseo/plugin";
import { useMemo } from "react";
import { Pressable, Text, View } from "react-native";
import type { Mosaic, MosaicCell } from "../shared/contracts";
import { CELL_STATES, type CellState } from "../shared/verdict";
import { Badge, Body, Card, Empty, Mono, Note } from "./parts";

/**
 * The corpus, drawn.
 *
 * One cell per obligation. The cell's colour is the promise's EPISTEMIC
 * STATUS — observed, declared, open, uncheckable, failed, waived — and the
 * gap kind is not a colour: it is a debugging detail, and it belongs to the
 * drill-down.
 *
 * The picture exists to make one thing unmissable: how much of the corpus
 * is discharged, by what kind of evidence, and how much of the store
 * reaches a promise at all. A reader who adds two numbers in two panels
 * arrives at a friendlier answer than the truth; a reader who looks at a
 * field of cells does not.
 */

const CELL_PITCH_COMPACT = 9;
const CELL_PITCH = 11;
const COLUMNS_COMPACT = 22;
const COLUMNS = 46;

export function cellColor(theme: PluginTheme, state: CellState): string {
  switch (state) {
    case "observed":
      return theme.colors.statusSuccess;
    case "declared":
      return theme.colors.accent;
    case "failed":
      return theme.colors.statusDanger;
    case "uncheckable":
      return theme.colors.statusWarning;
    case "open":
      return theme.colors.surface2;
    case "waived":
      return theme.colors.surface2;
  }
}

export const CELL_LABEL: Record<CellState, string> = {
  observed: "observed — a machine run, current",
  declared: "declared — a person's word, current",
  open: "open — no current evidence",
  uncheckable: "uncheckable — the corpus names no check",
  failed: "failed — a decisive failure",
  waived: "waived — accepted by a named, expiring waiver",
};

function MosaicCellView({
  theme,
  cell,
  pitch,
  onPress,
}: {
  theme: PluginTheme;
  cell: MosaicCell;
  pitch: number;
  onPress: (cell: MosaicCell) => void;
}) {
  const styles = useMemo(
    () => ({
      cell: {
        width: pitch,
        height: pitch,
        borderRadius: 2,
        marginRight: 1,
        marginBottom: 1,
        backgroundColor: cellColor(theme, cell.state),
        borderWidth: cell.state === "waived" || cell.disagreement ? 1 : 0,
        borderColor:
          cell.state === "waived"
            ? theme.colors.statusWarning
            : cell.disagreement
              ? theme.colors.foreground
              : theme.colors.border,
      },
    }),
    [theme, cell.state, cell.disagreement, pitch],
  );
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${cell.decision} ${cell.obligation}: ${cell.state}`}
      onPress={() => onPress(cell)}
      style={styles.cell}
    />
  );
}

/**
 * The field: the whole corpus at once, packed in the kernel's own order.
 *
 * The cells of one decision are contiguous, and a decision's first cell
 * carries a left margin, so the bands are visible without a label.
 */
function MosaicField({
  theme,
  cells,
  pitch,
  columns,
  onPress,
}: {
  theme: PluginTheme;
  cells: MosaicCell[];
  pitch: number;
  columns: number;
  onPress: (cell: MosaicCell) => void;
}) {
  const rows = useMemo(() => {
    const out: MosaicCell[][] = [];
    for (let index = 0; index < cells.length; index += columns) {
      out.push(cells.slice(index, index + columns));
    }
    return out;
  }, [cells, columns]);

  const styles = useMemo(
    () => ({
      field: {
        flexDirection: "row" as const,
        flexWrap: "wrap" as const,
        gap: 1,
      },
    }),
    [],
  );

  let previousDecision = "";
  return (
    <View style={styles.field}>
      {rows.map((row, rowIndex) => (
        <View
          key={rowIndex}
          style={{ flexDirection: "row", flexWrap: "wrap", width: "100%" }}
        >
          {row.map((cell) => {
            const isNewDecision = cell.decision !== previousDecision;
            previousDecision = cell.decision;
            return (
              <View key={`${cell.decision}/${cell.obligation}`} style={{ marginLeft: isNewDecision ? 4 : 0 }}>
                <MosaicCellView theme={theme} cell={cell} pitch={pitch} onPress={onPress} />
              </View>
            );
          })}
        </View>
      ))}
    </View>
  );
}

/**
 * The bands: one row per decision that has something open in it.
 *
 * The field shows the shape; the bands show the address. A decision whose
 * promises are all observed is not listed: there is nothing to do about it,
 * and a list of 155 rows where 80 say "nothing" is a list nobody reads.
 */
function MosaicBands({
  theme,
  cells,
  onOpen,
}: {
  theme: PluginTheme;
  cells: MosaicCell[];
  onOpen: (decisionId: string) => void;
}) {
  const bands = useMemo(() => {
    const byDecision = new Map<string, MosaicCell[]>();
    for (const cell of cells) {
      const list = byDecision.get(cell.decision) ?? [];
      list.push(cell);
      byDecision.set(cell.decision, list);
    }
    const out: { decision: string; cells: MosaicCell[]; worst: MosaicCell["state"] }[] = [];
    for (const [decision, decisionCells] of byDecision) {
      const worst = worstOf(decisionCells);
      if (worst === "observed") continue;
      out.push({ decision, cells: decisionCells, worst });
    }
    const order: Record<MosaicCell["state"], number> = {
      failed: 0,
      open: 1,
      uncheckable: 2,
      declared: 3,
      waived: 4,
      observed: 5,
    };
    out.sort((a, b) => order[a.worst] - order[b.worst] || a.decision.localeCompare(b.decision));
    return out;
  }, [cells]);

  const styles = useMemo(
    () => ({
      band: {
        flexDirection: "row" as const,
        alignItems: "center" as const,
        gap: 6,
        paddingVertical: 3,
      },
      cells: { flexDirection: "row" as const, flexWrap: "wrap" as const, flex: 1 },
      name: {
        color: theme.colors.foreground,
        fontSize: 11,
        width: 190,
      },
      row: { flexDirection: "row" as const, alignItems: "center" as const, gap: 4 },
    }),
    [theme],
  );

  if (bands.length === 0) {
    return <Empty theme={theme}>Every promise in the corpus is observed.</Empty>;
  }

  return (
    <View>
      {bands.map((band) => (
        <Pressable
          key={band.decision}
          accessibilityRole="button"
          accessibilityLabel={`Open decision ${band.decision}`}
          onPress={() => onOpen(band.decision)}
          style={styles.band}
        >
          <Text style={styles.name} numberOfLines={1}>
            {band.decision}
          </Text>
          <View style={styles.cells}>
            {band.cells.map((cell) => (
              <MosaicCellView
                key={cell.obligation}
                theme={theme}
                cell={cell}
                pitch={8}
                onPress={() => onOpen(cell.decision)}
              />
            ))}
          </View>
        </Pressable>
      ))}
    </View>
  );
}

function worstOf(cells: MosaicCell[]): MosaicCell["state"] {
  const order: Record<MosaicCell["state"], number> = {
    failed: 0,
    open: 1,
    uncheckable: 2,
    declared: 3,
    waived: 4,
    observed: 5,
  };
  return cells.reduce<MosaicCell["state"]>(
    (worst, cell) => (order[cell.state] < order[worst] ? cell.state : worst),
    "observed",
  );
}

/**
 * The whole view.
 *
 * The join comes FIRST, because it is the fact the panels used to split in
 * two: how much of the store reaches a promise that is still live, and how
 * much of that discharges one.
 */
export function MosaicView({
  theme,
  compact,
  mosaic,
  onOpenCell,
  onOpenDecision,
}: {
  theme: PluginTheme;
  compact: boolean;
  mosaic: Mosaic;
  onOpenCell: (cell: MosaicCell) => void;
  onOpenDecision: (decisionId: string) => void;
}) {
  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      legend: { flexDirection: "row" as const, flexWrap: "wrap" as const, gap: 6 },
      join: { flexDirection: "row" as const, gap: 10, flexWrap: "wrap" as const },
      figure: { gap: 2, minWidth: 96 },
      value: { color: theme.colors.foreground, fontSize: 22, fontWeight: "700" as const },
      caption: { color: theme.colors.foregroundMuted, fontSize: 11 },
    }),
    [theme],
  );

  const pitch = compact ? CELL_PITCH_COMPACT : CELL_PITCH;
  const columns = compact ? COLUMNS_COMPACT : COLUMNS;

  if (mosaic.error !== null) {
    return (
      <Card theme={theme} title="The corpus">
        <Note theme={theme} tone="warn">
          {mosaic.error}
        </Note>
      </Card>
    );
  }

  return (
    <View style={styles.stack}>
      <Card
        theme={theme}
        title="The join"
        subtitle="how much of the attestation store reaches a promise"
      >
        <View style={styles.join}>
          <Figure theme={theme} value={mosaic.store.total} caption="attestations in the store" />
          <Figure
            theme={theme}
            value={mosaic.store.namingLivePromise}
            caption="name a promise that is still live"
          />
          <Figure
            theme={theme}
            value={mosaic.store.discharging}
            caption="actually discharge one"
          />
        </View>
        {mosaic.store.discharging < mosaic.store.namingLivePromise && (
          <Note theme={theme} tone="warn">
            {mosaic.store.namingLivePromise - mosaic.store.discharging} attestation(s) name a live
            promise and discharge none of it. An attestation is bound to the content of the scope
            it was made against; the corpus has moved under them.
          </Note>
        )}
      </Card>

      <Card theme={theme} title="The corpus" subtitle={`${mosaic.counts.total} promises`}>
        <View style={styles.legend}>
          {CELL_STATES.map((state) => (
            <LegendEntry
              key={state}
              theme={theme}
              state={state}
              count={mosaic.counts[state]}
            />
          ))}
        </View>
        <MosaicField
          theme={theme}
          cells={mosaic.cells}
          pitch={pitch}
          columns={columns}
          onPress={onOpenCell}
        />
        <Mono theme={theme}>
          {mosaic.counts.total} cells · one per promise · {mosaic.readings.disagreeing} read
          differently by two kernel commands
        </Mono>
      </Card>

      <Card theme={theme} title="The bands" subtitle="the decisions that have something open">
        <MosaicBands theme={theme} cells={mosaic.cells} onOpen={onOpenDecision} />
      </Card>

      <Card theme={theme} title="Two readings" subtitle="the kernel does not always agree with itself">
        <Body theme={theme} muted>
          packages: {mosaic.readings.packages}
        </Body>
        <Body theme={theme} muted>
          census: {mosaic.readings.census}
        </Body>
        {mosaic.readings.disagreeing > 0 && (
          <Note theme={theme} tone="info">
            {mosaic.readings.disagreeing} promise(s) are read differently by the two commands. The
            console shows both on the cell and does not pick a side.
          </Note>
        )}
      </Card>
    </View>
  );
}

function Figure({
  theme,
  value,
  caption,
}: {
  theme: PluginTheme;
  value: number;
  caption: string;
}) {
  const styles = useMemo(
    () => ({
      figure: { gap: 2, minWidth: 96 },
      value: { color: theme.colors.foreground, fontSize: 22, fontWeight: "700" as const },
      caption: { color: theme.colors.foregroundMuted, fontSize: 11 },
    }),
    [theme],
  );
  return (
    <View style={styles.figure}>
      <Text style={styles.value}>{value}</Text>
      <Text style={styles.caption}>{caption}</Text>
    </View>
  );
}

function LegendEntry({
  theme,
  state,
  count,
}: {
  theme: PluginTheme;
  state: CellState;
  count: number;
}) {
  const styles = useMemo(
    () => ({
      entry: { flexDirection: "row" as const, alignItems: "center" as const, gap: 5 },
      swatch: {
        width: 11,
        height: 11,
        borderRadius: 2,
        backgroundColor: cellColor(theme, state),
        borderWidth: state === "waived" ? 1 : 0,
        borderColor: theme.colors.statusWarning,
      },
      label: { color: theme.colors.foregroundMuted, fontSize: 11 },
      count: { color: theme.colors.foreground, fontSize: 11, fontWeight: "600" as const },
    }),
    [theme, state],
  );
  return (
    <View style={styles.entry}>
      <View style={styles.swatch} />
      <Text style={styles.label}>{state}</Text>
      <Text style={styles.count}>{count}</Text>
    </View>
  );
}
