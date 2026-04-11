"use client";

import * as RadixTooltip from "@radix-ui/react-tooltip";
import type { ReactNode } from "react";

export function TooltipProvider({ children }: { children: ReactNode }) {
  return (
    <RadixTooltip.Provider delayDuration={300}>
      {children}
    </RadixTooltip.Provider>
  );
}

export function Tooltip({ label, children }: { label: string; children: ReactNode }) {
  return (
    <RadixTooltip.Root>
      <RadixTooltip.Trigger asChild>{children}</RadixTooltip.Trigger>
      <RadixTooltip.Portal>
        <RadixTooltip.Content
          side="right"
          sideOffset={8}
          className="z-50 rounded bg-atlas-surface px-2.5 py-1.5 text-xs text-atlas-text shadow-lg border border-atlas-border"
        >
          {label}
          <RadixTooltip.Arrow className="fill-atlas-surface" />
        </RadixTooltip.Content>
      </RadixTooltip.Portal>
    </RadixTooltip.Root>
  );
}
