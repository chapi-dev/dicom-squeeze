import { fireEvent, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';

import App from '../App';

describe('App', () => {
  it('renders the headline and the disclaimer', () => {
    render(<App />);
    expect(screen.getByRole('heading', { name: /dicom squeeze/i })).toBeInTheDocument();
    expect(screen.getByText(/not a medical device/i)).toBeInTheDocument();
  });

  it('exposes every estate control as a labelled slider', () => {
    render(<App />);
    expect(screen.getByLabelText(/archive size today/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/new studies per year/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/retention horizon/i)).toBeInTheDocument();
  });

  it('starts on the HTJ2K codec', () => {
    render(<App />);
    const selected = screen.getByRole('radio', { name: /high-throughput jpeg 2000/i });
    expect(selected).toHaveAttribute('aria-checked', 'true');
  });

  it('switches the selected codec when another one is picked', async () => {
    const user = userEvent.setup();
    render(<App />);

    const jpegLs = screen.getByRole('radio', { name: /jpeg-ls lossless/i });
    await user.click(jpegLs);

    expect(jpegLs).toHaveAttribute('aria-checked', 'true');
    expect(screen.getByRole('radio', { name: /high-throughput jpeg 2000/i })).toHaveAttribute(
      'aria-checked',
      'false',
    );
  });

  it('drops the yearly saving to zero on the uncompressed baseline', async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole('radio', { name: /explicit vr little endian/i }));

    const card = screen.getByText(/storage saved per year/i).closest('div');
    expect(card).not.toBeNull();
    expect(within(card as HTMLElement).getByText('0,00 €')).toBeInTheDocument();
  });

  it('lists one comparison row per codec', () => {
    render(<App />);
    const table = screen.getByRole('table');
    expect(within(table).getAllByRole('row')).toHaveLength(7);
  });

  it('shows a larger archive when the estate slider grows', () => {
    render(<App />);
    expect(screen.getByText(/^From 3 PB/)).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText(/archive size today/i), {
      target: { value: '6' },
    });

    expect(screen.getByText(/^From 6 PB/)).toBeInTheDocument();
  });

  it('raises the storage bill when everything moves to the hot tier', () => {
    render(<App />);
    const bill = () =>
      within(
        screen.getByText(/storage saved per year/i).closest('div') as HTMLElement,
      ).getByText(/Bill drops from/).textContent;

    const before = bill();
    fireEvent.change(screen.getByLabelText(/^Hot/), { target: { value: '100' } });
    fireEvent.change(screen.getByLabelText(/^Cold/), { target: { value: '0' } });
    fireEvent.change(screen.getByLabelText(/^Cool/), { target: { value: '0' } });

    expect(bill()).not.toBe(before);
  });
});
