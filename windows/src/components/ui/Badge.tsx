import * as React from "react";
import { cn } from "../../lib/utils";

export interface BadgeProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: "default" | "secondary" | "destructive" | "outline" | "mint" | "amber" | "indigo" | "blue";
}

export function Badge({ className, variant = "default", ...props }: BadgeProps) {
  const variantStyles = {
    default: "border-transparent bg-slate-900 text-white shadow hover:bg-slate-800",
    secondary: "border-transparent bg-slate-100 text-slate-900 hover:bg-slate-200",
    destructive: "border-transparent bg-red-100 text-red-700 hover:bg-red-200",
    outline: "text-slate-700 border-slate-200",
    mint: "border-emerald-200 bg-emerald-50 text-emerald-700 font-medium",
    amber: "border-amber-200 bg-amber-50 text-amber-700 font-medium",
    indigo: "border-indigo-200 bg-indigo-50 text-indigo-700 font-medium",
    blue: "border-blue-200 bg-blue-50 text-blue-700 font-medium",
  };

  return (
    <div
      className={cn(
        "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2",
        variantStyles[variant],
        className
      )}
      {...props}
    />
  );
}
