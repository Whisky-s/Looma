import * as React from "react";
import { cn } from "../../lib/utils";

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "default" | "secondary" | "outline" | "ghost" | "link" | "destructive" | "pill";
  size?: "default" | "sm" | "lg" | "icon" | "pill";
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = "default", size = "default", ...props }, ref) => {
    const variantStyles = {
      default: "bg-[#2563eb] text-white hover:bg-blue-700 shadow-sm font-medium",
      secondary: "bg-slate-100 text-slate-900 hover:bg-slate-200 shadow-sm font-medium",
      outline: "border border-slate-200 bg-white text-slate-800 hover:bg-slate-50 shadow-sm font-medium",
      ghost: "text-slate-700 hover:bg-slate-100 hover:text-slate-900",
      link: "text-[#2563eb] underline-offset-4 hover:underline",
      destructive: "bg-red-500 text-white hover:bg-red-600 shadow-sm font-medium",
      pill: "bg-[#e0eeff] text-[#0266ee] hover:bg-blue-100 font-semibold rounded-full",
    };

    const sizeStyles = {
      default: "h-9 px-4 py-2 text-xs rounded-lg",
      sm: "h-8 px-3 text-xs rounded-md",
      lg: "h-10 px-8 text-sm rounded-lg",
      icon: "h-8 w-8 rounded-lg",
      pill: "h-7 px-3 text-xs rounded-full",
    };

    return (
      <button
        ref={ref}
        className={cn(
          "inline-flex items-center justify-center whitespace-nowrap text-xs transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 disabled:pointer-events-none disabled:opacity-50 select-none cursor-pointer",
          variantStyles[variant],
          sizeStyles[size],
          className
        )}
        {...props}
      />
    );
  }
);
Button.displayName = "Button";
