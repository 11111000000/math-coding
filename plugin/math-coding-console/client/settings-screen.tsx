import { useSettings } from "@getpaseo/plugin/client";
import {
  SettingsAction,
  SettingsCard,
  SettingsInput,
  SettingsSection,
} from "@getpaseo/plugin/client/ui";
import { useEffect, useState } from "react";
import { preferences } from "../shared/settings";

/**
 * The console's settings.
 *
 * Three things the console cannot guess: which repository to look at, which
 * identity a review is signed under, and what command `attest-batch --run`
 * executes when the console re-signs a changed scope.
 */
export function SettingsScreen() {
  const settings = useSettings(preferences);
  const [repoRoot, setRepoRoot] = useState("");
  const [reviewProducer, setReviewProducer] = useState("");
  const [attestRunCommand, setAttestRunCommand] = useState("");

  const revision = settings.status === "ready" || settings.status === "invalid" ? settings.revision : "";

  useEffect(() => {
    if (settings.status !== "ready") return;
    setRepoRoot(settings.values.repoRoot);
    setReviewProducer(settings.values.reviewProducer);
    setAttestRunCommand(settings.values.attestRunCommand);
  }, [settings.status, revision]);

  if (settings.status === "loading") {
    return <SettingsAction label="Settings" actionLabel="Loading" onPress={() => {}} disabled />;
  }
  if (settings.status === "error" || settings.status === "invalid") {
    return <SettingsAction label="Settings" actionLabel="Broken" onPress={() => {}} disabled />;
  }

  const save = () => {
    if (settings.status !== "ready") return;
    void settings.save(
      {
        repoRoot: repoRoot.trim(),
        kernelPath: settings.values.kernelPath,
        reviewProducer: reviewProducer.trim(),
        attestRunCommand: attestRunCommand.trim(),
        refreshSeconds: settings.values.refreshSeconds,
      },
      settings.revision,
    );
  };

  return (
    <>
      <SettingsSection
        title="Repository"
        info="The console reads the corpus and runs the kernel in this directory."
      >
        <SettingsCard>
          <SettingsInput
            label="Repository root"
            hint="Absolute path to the math-coding repository. Leave empty to use the workspace directory."
            initialValue={repoRoot}
            onChangeText={setRepoRoot}
            placeholder="/home/me/project"
          />
        </SettingsCard>
      </SettingsSection>

      <SettingsSection title="Reviews" info="The identity a review is signed under.">
        <SettingsCard>
          <SettingsInput
            label="Review producer"
            hint="Class-tagged: human:<name>, agent:<id> or ci:<job>. The attestation schema rejects an untagged identity."
            initialValue={reviewProducer}
            onChangeText={setReviewProducer}
            placeholder="human:reviewer"
          />
        </SettingsCard>
      </SettingsSection>

      <SettingsSection
        title="Re-signing"
        info="The command that produces the evidence a test attestation claims."
      >
        <SettingsCard>
          <SettingsInput
            label="Run command"
            hint="Executed once by mathc attest-batch --run. Its exit code becomes the result and its output digest the evidence."
            initialValue={attestRunCommand}
            onChangeText={setAttestRunCommand}
            placeholder="dune runtest"
          />
        </SettingsCard>
      </SettingsSection>

      <SettingsSection title="">
        <SettingsCard>
          <SettingsAction
            label="Save"
            hint={settings.saveError ?? "Store the values above."}
            error={settings.saveError}
            actionLabel={settings.saving ? "Saving…" : "Save"}
            disabled={settings.saving}
            onPress={save}
          />
        </SettingsCard>
      </SettingsSection>
    </>
  );
}
