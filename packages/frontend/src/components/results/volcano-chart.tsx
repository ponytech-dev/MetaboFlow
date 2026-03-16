'use client';

import { useRef, useState } from 'react';
import type { VolcanoData, VolcanoPoint } from '@/types/analysis';

interface Tooltip {
  x: number;
  y: number;
  point: VolcanoPoint;
}

interface VolcanoChartProps {
  data: VolcanoData | null;
  width?: number;
  height?: number;
}

const MARGIN = { top: 24, right: 24, bottom: 48, left: 56 };

export function VolcanoChart({ data, width = 560, height = 400 }: VolcanoChartProps) {
  const svgRef = useRef<SVGSVGElement>(null);
  const [tooltip, setTooltip] = useState<Tooltip | null>(null);

  if (!data || data.points.length === 0) {
    return (
      <div
        className="flex items-center justify-center rounded-lg border border-dashed border-border text-sm text-muted-foreground"
        style={{ width, height }}
      >
        No volcano data available.
      </div>
    );
  }

  const innerW = width - MARGIN.left - MARGIN.right;
  const innerH = height - MARGIN.top - MARGIN.bottom;

  // Compute data ranges with padding
  const allX = data.points.map((p) => p.log2fc);
  const allY = data.points.map((p) => p.neg_log10_pval);
  const xMax = Math.max(Math.abs(Math.min(...allX)), Math.abs(Math.max(...allX))) * 1.1 + 0.5;
  const yMax = Math.max(...allY) * 1.1 + 0.5;

  // Scale functions
  const scaleX = (v: number) => ((v + xMax) / (2 * xMax)) * innerW;
  const scaleY = (v: number) => innerH - (v / yMax) * innerH;

  // Axis ticks
  const xTicks = makeLinearTicks(-xMax, xMax, 7);
  const yTicks = makeLinearTicks(0, yMax, 6);

  // Cutoff lines in data coords
  const fcCut = Math.log2(data.fc_cutoff);
  const yCut = -Math.log10(data.pval_cutoff);

  function handleMouseMove(e: React.MouseEvent<SVGCircleElement>, point: VolcanoPoint) {
    const svg = svgRef.current;
    if (!svg) return;
    const rect = svg.getBoundingClientRect();
    setTooltip({
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
      point,
    });
  }

  function handleMouseLeave() {
    setTooltip(null);
  }

  return (
    <div className="relative select-none">
      <svg
        ref={svgRef}
        width={width}
        height={height}
        className="overflow-visible"
        style={{ maxWidth: '100%', height: 'auto' }}
      >
        <g transform={`translate(${MARGIN.left},${MARGIN.top})`}>
          {/* Grid lines */}
          {yTicks.map((t) => (
            <line
              key={t}
              x1={0}
              x2={innerW}
              y1={scaleY(t)}
              y2={scaleY(t)}
              stroke="currentColor"
              strokeOpacity={0.06}
              strokeWidth={1}
            />
          ))}
          {xTicks.map((t) => (
            <line
              key={t}
              x1={scaleX(t)}
              x2={scaleX(t)}
              y1={0}
              y2={innerH}
              stroke="currentColor"
              strokeOpacity={0.06}
              strokeWidth={1}
            />
          ))}

          {/* Cutoff lines */}
          {/* Horizontal p-value cutoff */}
          <line
            x1={0}
            x2={innerW}
            y1={scaleY(yCut)}
            y2={scaleY(yCut)}
            stroke="#6b7280"
            strokeWidth={1}
            strokeDasharray="4 3"
            opacity={0.6}
          />
          {/* Vertical FC cutoff (positive) */}
          <line
            x1={scaleX(fcCut)}
            x2={scaleX(fcCut)}
            y1={0}
            y2={innerH}
            stroke="#6b7280"
            strokeWidth={1}
            strokeDasharray="4 3"
            opacity={0.6}
          />
          {/* Vertical FC cutoff (negative) */}
          <line
            x1={scaleX(-fcCut)}
            x2={scaleX(-fcCut)}
            y1={0}
            y2={innerH}
            stroke="#6b7280"
            strokeWidth={1}
            strokeDasharray="4 3"
            opacity={0.6}
          />

          {/* Data points */}
          {data.points.map((pt) => {
            const cx = scaleX(pt.log2fc);
            const cy = scaleY(pt.neg_log10_pval);
            const fill =
              pt.significant === 'up'
                ? '#ef4444'
                : pt.significant === 'down'
                ? '#3b82f6'
                : '#9ca3af';
            const opacity = pt.significant === 'ns' ? 0.4 : 0.8;
            return (
              <circle
                key={pt.feature_id}
                cx={cx}
                cy={cy}
                r={3.5}
                fill={fill}
                opacity={opacity}
                className="cursor-pointer transition-opacity hover:opacity-100"
                onMouseMove={(e) => handleMouseMove(e, pt)}
                onMouseLeave={handleMouseLeave}
              />
            );
          })}

          {/* X axis */}
          <line
            x1={0}
            x2={innerW}
            y1={innerH}
            y2={innerH}
            stroke="currentColor"
            strokeOpacity={0.2}
          />
          {xTicks.map((t) => (
            <g key={t} transform={`translate(${scaleX(t)},${innerH})`}>
              <line y2={4} stroke="currentColor" strokeOpacity={0.3} />
              <text
                y={14}
                textAnchor="middle"
                fontSize={10}
                fill="currentColor"
                opacity={0.5}
              >
                {t}
              </text>
            </g>
          ))}
          <text
            x={innerW / 2}
            y={innerH + 36}
            textAnchor="middle"
            fontSize={11}
            fill="currentColor"
            opacity={0.6}
          >
            log₂(Fold Change)
          </text>

          {/* Y axis */}
          <line
            x1={0}
            x2={0}
            y1={0}
            y2={innerH}
            stroke="currentColor"
            strokeOpacity={0.2}
          />
          {yTicks.map((t) => (
            <g key={t} transform={`translate(0,${scaleY(t)})`}>
              <line x2={-4} stroke="currentColor" strokeOpacity={0.3} />
              <text
                x={-8}
                textAnchor="end"
                dominantBaseline="middle"
                fontSize={10}
                fill="currentColor"
                opacity={0.5}
              >
                {t.toFixed(1)}
              </text>
            </g>
          ))}
          <text
            transform={`translate(${-42},${innerH / 2}) rotate(-90)`}
            textAnchor="middle"
            fontSize={11}
            fill="currentColor"
            opacity={0.6}
          >
            -log₁₀(p-value)
          </text>
        </g>

        {/* Legend */}
        <g transform={`translate(${MARGIN.left + innerW - 120}, ${MARGIN.top + 8})`}>
          {[
            { color: '#ef4444', label: `Up (${data.points.filter((p) => p.significant === 'up').length})` },
            { color: '#3b82f6', label: `Down (${data.points.filter((p) => p.significant === 'down').length})` },
            { color: '#9ca3af', label: `NS (${data.points.filter((p) => p.significant === 'ns').length})` },
          ].map(({ color, label }, i) => (
            <g key={color} transform={`translate(0,${i * 16})`}>
              <circle cx={5} cy={5} r={4} fill={color} opacity={0.8} />
              <text x={14} y={9} fontSize={10} fill="currentColor" opacity={0.6}>
                {label}
              </text>
            </g>
          ))}
        </g>
      </svg>

      {/* Tooltip */}
      {tooltip && (
        <div
          className="pointer-events-none absolute z-10 max-w-[200px] rounded-md border border-border bg-popover px-3 py-2 text-xs shadow-lg"
          style={{
            left: tooltip.x + 12,
            top: tooltip.y - 8,
            transform:
              tooltip.x > width - 220 ? 'translateX(-110%)' : undefined,
          }}
        >
          <p className="font-semibold truncate">
            {tooltip.point.compound_name ?? tooltip.point.feature_id}
          </p>
          <p className="text-muted-foreground mt-0.5 font-mono text-[10px]">
            {tooltip.point.feature_id}
          </p>
          <div className="mt-1.5 space-y-0.5 text-muted-foreground">
            <p>log₂FC: <span className="text-foreground">{tooltip.point.log2fc.toFixed(3)}</span></p>
            <p>p-value: <span className="text-foreground">{tooltip.point.p_value.toExponential(3)}</span></p>
            <p>adj. p: <span className="text-foreground">{tooltip.point.adjusted_p_value.toExponential(3)}</span></p>
          </div>
        </div>
      )}
    </div>
  );
}

function makeLinearTicks(min: number, max: number, count: number): number[] {
  const step = (max - min) / (count - 1);
  return Array.from({ length: count }, (_, i) => {
    const v = min + i * step;
    // Round to 1 decimal
    return Math.round(v * 10) / 10;
  });
}
